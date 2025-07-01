//
//  VLMWrapper.mm
//  realingo_v3
//
//  Objective-C++ wrapper implementation
//

#import "VLMWrapper.h"

// Include framework headers
#import <llama/llama.h>

// Temporarily disable llava/clip functionality
#define VLM_SUPPORT_DISABLED 1

#ifndef VLM_SUPPORT_DISABLED
#import <llama/llava.h>
#import <llama/clip.h>
#endif

#include <vector>
#include <cstring>

@implementation VLMWrapper {
    llama_context* _llamaContext;
    llama_model* _model;
#ifndef VLM_SUPPORT_DISABLED
    clip_ctx* _clipContext;
#endif
    llama_batch _batch;
    llama_sampler* _sampler;
}

- (instancetype)initWithModelPath:(NSString*)modelPath clipPath:(NSString*)clipPath {
    self = [super init];
    if (self) {
        // Initialize llama backend
        llama_backend_init();
        
        // Load model
        llama_model_params model_params = llama_model_default_params();
        #if TARGET_OS_SIMULATOR
        model_params.n_gpu_layers = 0;
        #endif
        
        _model = llama_model_load_from_file([modelPath UTF8String], model_params);
        if (!_model) {
            NSLog(@"Failed to load model from %@", modelPath);
            return nil;
        }
        
        // Create context
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;
        ctx_params.n_threads = 4;
        ctx_params.n_threads_batch = 4;
        
        _llamaContext = llama_init_from_model(_model, ctx_params);
        if (!_llamaContext) {
            NSLog(@"Failed to create llama context");
            llama_model_free(_model);
            return nil;
        }
        
#ifndef VLM_SUPPORT_DISABLED
        // Load CLIP model if provided
        if (clipPath && clipPath.length > 0) {
            _clipContext = clip_model_load([clipPath UTF8String], 0);
            if (!_clipContext) {
                NSLog(@"Failed to load CLIP model from %@", clipPath);
            } else {
                // Validate embed size
                if (!llava_validate_embed_size(_llamaContext, _clipContext)) {
                    NSLog(@"CLIP model embed size mismatch!");
                    clip_free(_clipContext);
                    _clipContext = nullptr;
                }
            }
        }
#else
        NSLog(@"VLM support is disabled in this build");
#endif
        
        // Initialize batch
        _batch = llama_batch_init(512, 0, 1);
        
        // Initialize sampler
        llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
        _sampler = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(_sampler, llama_sampler_init_temp(0.1f));
        llama_sampler_chain_add(_sampler, llama_sampler_init_dist(1234));
    }
    return self;
}

- (void)dealloc {
    if (_sampler) {
        llama_sampler_free(_sampler);
    }
    llama_batch_free(_batch);
#ifndef VLM_SUPPORT_DISABLED
    if (_clipContext) {
        clip_free(_clipContext);
    }
#endif
    if (_llamaContext) {
        llama_free(_llamaContext);
    }
    if (_model) {
        llama_model_free(_model);
    }
    llama_backend_free();
}

- (struct llava_image_embed*)createImageEmbedFromData:(NSData*)imageData {
#ifndef VLM_SUPPORT_DISABLED
    if (!_clipContext) {
        NSLog(@"CLIP context not initialized");
        return nullptr;
    }
    
    const unsigned char* bytes = (const unsigned char*)imageData.bytes;
    int n_threads = MIN(4, [[NSProcessInfo processInfo] processorCount]);
    
    return llava_image_embed_make_with_bytes(_clipContext, n_threads, bytes, (int)imageData.length);
#else
    NSLog(@"VLM support is disabled");
    return nullptr;
#endif
}

- (void)freeImageEmbed:(struct llava_image_embed*)embed {
#ifndef VLM_SUPPORT_DISABLED
    if (embed) {
        llava_image_embed_free(embed);
    }
#endif
}

- (BOOL)evaluateImageEmbed:(struct llava_image_embed*)embed nPast:(int*)nPast {
#ifndef VLM_SUPPORT_DISABLED
    if (!embed || !_llamaContext) {
        return NO;
    }
    
    return llava_eval_image_embed(_llamaContext, embed, _batch.n_tokens, nPast);
#else
    return NO;
#endif
}

- (NSString*)generateResponseWithPrompt:(NSString*)prompt imageData:(NSData*)imageData {
#ifndef VLM_SUPPORT_DISABLED
    if (!_llamaContext || !_clipContext) {
        return @"Error: Model not properly initialized";
    }
#else
    return @"Error: VLM support is disabled in this build";
#endif
    
    // Clear context - remove all sequences
    llama_memory_seq_rm(llama_get_memory(_llamaContext), -1, -1, -1);
    
    // Create image embedding
    struct llava_image_embed* imageEmbed = [self createImageEmbedFromData:imageData];
    if (!imageEmbed) {
        return @"Error: Failed to create image embedding";
    }
    
    // Evaluate image
    int n_past = 0;
    BOOL success = [self evaluateImageEmbed:imageEmbed nPast:&n_past];
    [self freeImageEmbed:imageEmbed];
    
    if (!success) {
        return @"Error: Failed to evaluate image";
    }
    
    // Tokenize prompt
    NSArray<NSNumber*>* tokens = [self tokenize:prompt addBos:NO];
    
    // Evaluate prompt tokens
    _batch.n_tokens = 0;
    for (int i = 0; i < tokens.count; i++) {
        _batch.token[_batch.n_tokens] = tokens[i].intValue;
        _batch.pos[_batch.n_tokens] = n_past + i;
        _batch.n_seq_id[_batch.n_tokens] = 1;
        _batch.seq_id[_batch.n_tokens][0] = 0;
        _batch.logits[_batch.n_tokens] = (i == tokens.count - 1) ? 1 : 0;
        _batch.n_tokens++;
    }
    
    if (llama_decode(_llamaContext, _batch) != 0) {
        return @"Error: Failed to decode prompt";
    }
    
    n_past += tokens.count;
    
    // Generate response
    NSMutableString* response = [NSMutableString string];
    int maxTokens = 512;
    
    for (int i = 0; i < maxTokens; i++) {
        // Sample next token
        llama_token new_token = llama_sampler_sample(_sampler, _llamaContext, _batch.n_tokens - 1);
        
        // Check for end of generation
        if (llama_vocab_is_eog(llama_model_get_vocab(_model), new_token)) {
            break;
        }
        
        // Convert token to string
        NSString* tokenStr = [self tokenToString:new_token];
        [response appendString:tokenStr];
        
        // Prepare next batch
        _batch.n_tokens = 0;
        _batch.token[_batch.n_tokens] = new_token;
        _batch.pos[_batch.n_tokens] = n_past;
        _batch.n_seq_id[_batch.n_tokens] = 1;
        _batch.seq_id[_batch.n_tokens][0] = 0;
        _batch.logits[_batch.n_tokens] = 1;
        _batch.n_tokens++;
        n_past++;
        
        // Evaluate
        if (llama_decode(_llamaContext, _batch) != 0) {
            break;
        }
    }
    
    return response;
}

- (NSArray<NSNumber*>*)tokenize:(NSString*)text addBos:(BOOL)addBos {
    const char* utf8 = [text UTF8String];
    int utf8_len = strlen(utf8);
    int n_tokens = utf8_len + (addBos ? 1 : 0) + 1;
    
    std::vector<llama_token> tokens(n_tokens);
    const llama_vocab* vocab = llama_model_get_vocab(_model);
    int token_count = llama_tokenize(vocab, utf8, utf8_len, tokens.data(), n_tokens, addBos, false);
    
    if (token_count < 0) {
        return @[];
    }
    
    tokens.resize(token_count);
    
    NSMutableArray<NSNumber*>* result = [NSMutableArray arrayWithCapacity:token_count];
    for (llama_token token : tokens) {
        [result addObject:@(token)];
    }
    
    return result;
}

- (NSString*)tokenToString:(int)token {
    char buffer[256];
    const llama_vocab* vocab = llama_model_get_vocab(_model);
    int n = llama_token_to_piece(vocab, token, buffer, sizeof(buffer), 0, false);
    
    if (n <= 0) {
        return @"";
    }
    
    return [[NSString alloc] initWithBytes:buffer length:n encoding:NSUTF8StringEncoding] ?: @"";
}

- (BOOL)evaluateTokens:(NSArray<NSNumber*>*)tokens {
    _batch.n_tokens = 0;
    
    for (int i = 0; i < tokens.count; i++) {
        _batch.token[_batch.n_tokens] = tokens[i].intValue;
        _batch.pos[_batch.n_tokens] = i;
        _batch.n_seq_id[_batch.n_tokens] = 1;
        _batch.seq_id[_batch.n_tokens][0] = 0;
        _batch.logits[_batch.n_tokens] = (i == tokens.count - 1) ? 1 : 0;
        _batch.n_tokens++;
    }
    
    return llama_decode(_llamaContext, _batch) == 0;
}

- (void)clearContext {
    // Remove all sequences
    llama_memory_seq_rm(llama_get_memory(_llamaContext), -1, -1, -1);
}

- (NSString*)modelInfo {
    char buffer[256];
    llama_model_desc(_model, buffer, sizeof(buffer));
    return [NSString stringWithUTF8String:buffer];
}

// Property getters
- (struct llama_context*)llamaContext {
    return _llamaContext;
}

- (struct clip_ctx*)clipContext {
#ifndef VLM_SUPPORT_DISABLED
    return _clipContext;
#else
    return nullptr;
#endif
}

- (struct llama_model*)model {
    return _model;
}

@end