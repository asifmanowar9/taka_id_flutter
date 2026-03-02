"""
Bangladeshi Banknote Classifier — Keras to TFLite Converter
============================================================
Run this script ONCE (outside Flutter) to convert your trained
Keras model (.keras / .h5) into a TensorFlow Lite model (.tflite)
that the Flutter app can use.

Requirements:
    pip install tensorflow

Usage:
    python tools/convert_model.py --model path/to/your_model.keras
                                  --output assets/model/banknote_classifier.tflite
                                  --input_size 224

After running, copy the .tflite file into:
    taka_id/assets/model/banknote_classifier.tflite
"""

import argparse
import os
import numpy as np
import tensorflow as tf


def convert(model_path: str, output_path: str, input_size: int, quantize: bool):
    print(f"[1/4] Loading model from: {model_path}")
    model = tf.keras.models.load_model(model_path)
    model.summary()

    # ── Print the expected input shape so you can confirm in classifier.dart ──
    in_shape = model.input_shape  # e.g. (None, 224, 224, 3)
    print(f"\n  ► Model input shape  : {in_shape}")
    print(f"  ► Model output shape : {model.output_shape}")
    print(f"  ► Number of classes  : {model.output_shape[-1]}")

    print("\n[2/4] Creating TFLite converter …")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantize:
        # Post-training dynamic-range quantization — smaller model, near same accuracy
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        print("  ► Quantization: DEFAULT (dynamic-range)")
    else:
        print("  ► Quantization: none (float32)")

    print("[3/4] Converting …")
    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_kb = os.path.getsize(output_path) / 1024
    print(f"[4/4] Saved → {output_path}  ({size_kb:.1f} KB)")
    print("\n✅  Done!  Copy the .tflite file to:  assets/model/banknote_classifier.tflite")
    print(
        f"\n⚠️  Make sure the INPUT SIZE in lib/services/classifier.dart "
        f"matches your model's expected input ({in_shape[1]}×{in_shape[2]})."
    )


def verify(tflite_path: str, input_size: int):
    """Quick sanity-check: run a blank image through the converted model."""
    print("\n── Verification ──")
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    in_det  = interpreter.get_input_details()[0]
    out_det = interpreter.get_output_details()[0]
    print(f"  Input  tensor: shape={in_det['shape']}  dtype={in_det['dtype']}")
    print(f"  Output tensor: shape={out_det['shape']} dtype={out_det['dtype']}")

    dummy = np.zeros((1, input_size, input_size, 3), dtype=np.float32)
    interpreter.set_tensor(in_det["index"], dummy)
    interpreter.invoke()
    output = interpreter.get_tensor(out_det["index"])
    print(f"  Sample output (blank image): {output}")
    print("  Verification passed ✓")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert Keras model to TFLite")
    parser.add_argument(
        "--model",
        required=True,
        help="Path to your .keras or .h5 model file",
    )
    parser.add_argument(
        "--output",
        default="assets/model/banknote_classifier.tflite",
        help="Output path for the .tflite file (default: assets/model/banknote_classifier.tflite)",
    )
    parser.add_argument(
        "--input_size",
        type=int,
        default=224,
        help="Square input size the model was trained on (default: 224)",
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        help="Apply post-training quantization to reduce file size",
    )
    parser.add_argument(
        "--no_verify",
        action="store_true",
        help="Skip the sanity-check inference step",
    )
    args = parser.parse_args()

    convert(args.model, args.output, args.input_size, args.quantize)

    if not args.no_verify:
        verify(args.output, args.input_size)
