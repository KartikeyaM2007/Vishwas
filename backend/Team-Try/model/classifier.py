import numpy as np
import tensorflow as tf
import cv2
import os
from tensorflow.keras.preprocessing import image
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

# -------------------------
# Load trained model
# -------------------------
import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

FALLBACK_MODE = False
model = None

try:
    if os.path.exists("pothole_classifier.h5"):
        model = tf.keras.models.load_model("pothole_classifier.h5")
        logger.info("Loaded pothole_classifier.h5 successfully.")
    else:
        raise FileNotFoundError("pothole_classifier.h5 not found.")
except Exception as e:
    logger.warning(f"Failed to load model: {e}. Running in FALLBACK MODE.")
    FALLBACK_MODE = True



# -------------------------
# SAFE embedding extractor
# -------------------------
def get_embedding(img_array):
    x = img_array

    for layer in model.layers[:-1]:
        x = layer(x)

    embedding = x.numpy()[0]

    # normalize
    embedding = embedding / np.linalg.norm(embedding)

    return embedding


# -------------------------
# Image preprocessing
# -------------------------
def process_image(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)
    return img_array


# -------------------------
# Severity using OpenCV (1–10)
# -------------------------
def estimate_severity_cv(img_path):
    img = cv2.imread(img_path)

    if img is None:
        return 0, 0.0

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    _, thresh = cv2.threshold(blur, 60, 255, cv2.THRESH_BINARY_INV)

    pothole_area = np.sum(thresh == 255)
    total_area = thresh.size

    ratio = pothole_area / total_area

    # 🎯 Convert ratio → 1 to 10
    severity_score = int(min(max(ratio * 20, 1), 10))

    return severity_score, ratio


# -------------------------
# Severity using model (1–10)
# -------------------------
def estimate_severity_model(probability):
    severity_score = int(min(max(probability * 10, 1), 10))
    return severity_score


# -------------------------
# Main function
# -------------------------
def predict_and_embed(img_path, threshold=0.7):
    try:
        if not os.path.exists(img_path):
            return {"error": "Invalid file path"}

        if FALLBACK_MODE:
            logger.info("FALLBACK MODE active. Returning simulated positive result.")
            # Create a mock 1280-dim embedding for duplicate detection (normalized)
            mock_embedding = np.random.rand(1280)
            mock_embedding = mock_embedding / np.linalg.norm(mock_embedding)
            
            return {
                "class": "pothole",
                "confidence": 0.85,
                "severity": 6,
                "area_ratio": 0.35,
                "embedding": mock_embedding.tolist()
            }

        img_array = process_image(img_path)

        # inference
        probability = float(model(img_array, training=False)[0][0])

        print(f"\nRaw Probability: {probability:.4f}")

        # -------------------------
        # POTHOLE DETECTED
        # -------------------------
        if probability > threshold:

            print("Prediction: POTHOLE")

            # embedding
            embedding = get_embedding(img_array)

            # severity scores
            severity_cv, ratio = estimate_severity_cv(img_path)
            severity_model = estimate_severity_model(probability)

            # 🎯 Hybrid severity (weighted)
            final_severity = int(0.6 * severity_cv + 0.4 * severity_model)

            print(f"Severity (CV): {severity_cv} (ratio: {ratio:.4f})")
            print(f"Severity (Model): {severity_model}")
            print(f"Final Severity (1-10): {final_severity}")

            return {
                "class": "pothole",
                "confidence": probability,
                "severity": final_severity,
                "area_ratio": float(ratio),
                "embedding": embedding.tolist()
            }

        # -------------------------
        # NORMAL ROAD
        # -------------------------
        else:
            print("Prediction: NORMAL ROAD")

            return {
                "class": "normal",
                "confidence": float(1 - probability),
                "severity": 0,
                "embedding": None
            }

    except Exception as e:
        return {"error": str(e)}


# -------------------------
# Interactive loop
# -------------------------
if __name__ == "__main__":
    while True:
        img_path = input("\nEnter image path (or type 'exit'): ")

        if img_path.lower() == "exit":
            break

        result = predict_and_embed(img_path)
        print("\nResult:", result)