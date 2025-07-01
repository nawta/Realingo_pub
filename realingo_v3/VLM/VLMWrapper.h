//
//  VLMWrapper.h
//  realingo_v3
//
//  Objective-C++ wrapper for llama.cpp VLM functionality
//

#import <Foundation/Foundation.h>

// Forward declarations with struct tags
struct llama_context;
struct llama_model;
#ifndef VLM_SUPPORT_DISABLED
struct clip_ctx;
struct llava_image_embed;
#endif

@interface VLMWrapper : NSObject

// Properties
@property (readonly) struct llama_context* llamaContext;
@property (readonly) struct clip_ctx* clipContext;
@property (readonly) struct llama_model* model;

// Initialization
- (instancetype)initWithModelPath:(NSString*)modelPath clipPath:(NSString*)clipPath;

// VLM Functions
#ifndef VLM_SUPPORT_DISABLED
- (struct llava_image_embed*)createImageEmbedFromData:(NSData*)imageData;
- (void)freeImageEmbed:(struct llava_image_embed*)embed;
- (BOOL)evaluateImageEmbed:(struct llava_image_embed*)embed nPast:(int*)nPast;
#endif
- (NSString*)generateResponseWithPrompt:(NSString*)prompt imageData:(NSData*)imageData;

// Token Functions
- (NSArray<NSNumber*>*)tokenize:(NSString*)text addBos:(BOOL)addBos;
- (NSString*)tokenToString:(int)token;
- (BOOL)evaluateTokens:(NSArray<NSNumber*>*)tokens;

// Utility
- (void)clearContext;
- (NSString*)modelInfo;

@end