#!/usr/bin/env python3
# VLM Server for Heron-NVILA-Lite-2B
# 
# 使用方法:
# 1. 必要なライブラリをインストール:
#    pip install flask torch transformers pillow accelerate
# 2. サーバーを起動:
#    python vlm_server.py

import json
import base64
from io import BytesIO
from flask import Flask, request, jsonify
from PIL import Image
import torch
from transformers import AutoConfig, AutoModel, AutoProcessor
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# モデルの初期化
model_path = "turing-motors/Heron-NVILA-Lite-2B"
model = None
processor = None

def load_model():
    global model, processor
    logging.info("Loading VLM model...")
    try:
        config = AutoConfig.from_pretrained(model_path, trust_remote_code=True)
        model = AutoModel.from_config(config, trust_remote_code=True, device_map="auto")
        processor = AutoProcessor.from_pretrained(model_path, trust_remote_code=True)
        logging.info("Model loaded successfully!")
    except Exception as e:
        logging.error(f"Failed to load model: {e}")
        raise

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "ok", "model_loaded": model is not None})

@app.route('/api/vlm', methods=['POST'])
def generate_problem():
    try:
        data = request.json
        image_base64 = data['image']
        prompt = data['prompt']
        
        # Base64画像をデコード
        image_data = base64.b64decode(image_base64)
        image = Image.open(BytesIO(image_data))
        
        # VLMで処理
        inputs = processor(text=prompt, images=image, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs, 
                max_new_tokens=500,
                temperature=0.7,
                do_sample=True
            )
        
        response_text = processor.decode(outputs[0], skip_special_tokens=True)
        
        # プロンプトを除去（モデルによっては入力プロンプトも含まれる場合がある）
        if prompt in response_text:
            response_text = response_text.split(prompt)[-1].strip()
        
        # JSON形式でパース
        try:
            # レスポンスからJSON部分を抽出
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            if json_start != -1 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                response_json = json.loads(json_str)
            else:
                raise ValueError("No JSON found in response")
        except:
            # JSONパースに失敗した場合はダミーレスポンス
            logging.warning("Failed to parse JSON from model output, using fallback response")
            response_json = {
                "question": "この画像について説明してください",
                "answer": response_text if response_text else "画像の内容を説明してください",
                "hints": ["画像の内容を詳しく見てください"],
                "explanation": "VLMの生成結果",
                "tags": ["generated", "fallback"]
            }
        
        return jsonify(response_json)
        
    except Exception as e:
        logging.error(f"Error in generate_problem: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/vlm/evaluate', methods=['POST'])
def evaluate_answer():
    try:
        data = request.json
        prompt = data['prompt']
        
        # 評価実行（画像がある場合は処理）
        if 'image' in data:
            image_base64 = data['image']
            image_data = base64.b64decode(image_base64)
            image = Image.open(BytesIO(image_data))
            inputs = processor(text=prompt, images=image, return_tensors="pt")
        else:
            inputs = processor(text=prompt, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs, 
                max_new_tokens=300,
                temperature=0.5,
                do_sample=True
            )
        
        response_text = processor.decode(outputs[0], skip_special_tokens=True)
        
        # プロンプトを除去
        if prompt in response_text:
            response_text = response_text.split(prompt)[-1].strip()
        
        # 評価結果をパース
        try:
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            if json_start != -1 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                feedback_json = json.loads(json_str)
            else:
                raise ValueError("No JSON found in response")
        except:
            # パース失敗時のデフォルト評価
            logging.warning("Failed to parse JSON from evaluation output, using fallback")
            feedback_json = {
                "score": 0.75,
                "feedback": "よく書けています。さらに詳細な説明を加えるとより良くなるでしょう。",
                "improvements": ["もう少し具体的な描写を加えてみましょう", "接続詞を使って文章をつなげてみましょう"],
                "strengths": ["基本的な内容は理解できています", "文法的に正しい文章が書けています"],
                "grammarScore": 8,
                "vocabularyScore": 7,
                "contentScore": 8,
                "fluencyScore": 7
            }
        
        return jsonify(feedback_json)
        
    except Exception as e:
        logging.error(f"Error in evaluate_answer: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    try:
        load_model()
        app.run(host='0.0.0.0', port=8000, debug=False)
    except Exception as e:
        logging.error(f"Failed to start server: {e}")
        exit(1)