# services/cloudinary.py

import cloudinary
import cloudinary.uploader
from utils.config import CLOUDINARY_CONFIG

cloudinary.config(
    cloud_name=CLOUDINARY_CONFIG["cloud_name"],
    api_key=CLOUDINARY_CONFIG["api_key"],
    api_secret=CLOUDINARY_CONFIG["api_secret"]
)

def upload_image(file):
    result = cloudinary.uploader.upload(file)
    return result["secure_url"]

def upload_media(file, media_type="image"):
    resource_type = "video" if media_type == "video" else "image"
    result = cloudinary.uploader.upload(file, resource_type=resource_type)
    return result["secure_url"]
