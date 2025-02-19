import os
import requests
from tqdm import tqdm

# Set the models directory
models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

# Create models directory if it doesn't exist
os.makedirs(models_dir, exist_ok=True)

# Define base URL
BASE_URL = "https://github.com/danielgatis/rembg/releases/download/v0.0.0/"

# Define models and their filenames, please check models you need
MODELS = {
    "u2net": "u2net.onnx",
    #u2netp": "u2netp.onnx",
    # "u2net_human_seg": "u2net_human_seg.onnx",
    # "u2net_cloth_seg": "u2net_cloth_seg.onnx",
    # "silueta": "silueta.onnx",
    "isnet-general-use": "isnet-general-use.onnx",
    # "isnet-anime": "isnet-anime.onnx",
    # "sam-encoder": "vit_b-encoder-quant.onnx",
    # "sam-decoder": "vit_b-decoder-quant.onnx",
    "birefnet-general": "BiRefNet-general-epoch_244.onnx",
    # "birefnet-general-lite": "BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx",
    # "birefnet-portrait": "BiRefNet-portrait-epoch_150.onnx",
    # "birefnet-dis": "BiRefNet-DIS-epoch_590.onnx",
    # "birefnet-hrsod": "BiRefNet-HRSOD_DHU-epoch_115.onnx",
    # "birefnet-cod": "BiRefNet-COD-epoch_125.onnx",
    # "birefnet-massive": "BiRefNet-massive-TR_DIS5K_TR_TEs-epoch_420.onnx"
}


def download_file(url, filepath):
    """
    Download a file with progress bar
    """
    response = requests.get(url, stream=True)
    response.raise_for_status()
    total_size = int(response.headers.get("content-length", 0))

    with (
        open(filepath, "wb") as f,
        tqdm(
            desc=os.path.basename(filepath),
            total=total_size,
            unit="iB",
            unit_scale=True,
            unit_divisor=1024,
        ) as pbar,
    ):
        for data in response.iter_content(chunk_size=1024):
            size = f.write(data)
            pbar.update(size)


def main():
    print("Starting model downloads...")

    for model_name, filename in MODELS.items():
        output_filename = f"{model_name}.onnx"
        output_path = os.path.join(models_dir, output_filename)

        if os.path.exists(output_path):
            print(f"Model {output_filename} already exists, skipping...")
            continue

        url = BASE_URL + filename
        print(f"\nDownloading {model_name}...")
        try:
            download_file(url, output_path)
            print(f"Successfully downloaded {model_name}")
        except Exception as e:
            print(f"Error downloading {model_name}: {str(e)}")


if __name__ == "__main__":
    main()
