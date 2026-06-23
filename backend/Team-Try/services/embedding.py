# services/embedding.py

import torch
from torchvision import models, transforms
from PIL import Image
import requests
from io import BytesIO

model = models.mobilenet_v2(pretrained=True)
model.classifier = torch.nn.Identity()
model.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])

def get_embedding(image_url):
    response = requests.get(image_url)
    img = Image.open(BytesIO(response.content)).convert("RGB")
    img = transform(img).unsqueeze(0)

    with torch.no_grad():
        embedding = model(img)

    return embedding.squeeze().numpy()