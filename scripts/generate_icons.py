#!/usr/bin/env python3
"""Batch-generate Merge Arena item icons via ComfyUI HTTP API.

Usage:
    python3 scripts/generate_icons.py              # generate all 111 items
    python3 scripts/generate_icons.py --chain Me    # one chain only
    python3 scripts/generate_icons.py --item me_3   # single item
    python3 scripts/generate_icons.py --dry-run     # print prompts, don't generate
    python3 scripts/generate_icons.py --no-skip     # regenerate existing files

Requires ComfyUI running at http://127.0.0.1:8188 with --lowvram.
"""

import argparse
import json
import os
import random
import sys
import time
import uuid
import urllib.request
import urllib.parse
import urllib.error

SERVER = "http://127.0.0.1:8188"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "icons", "raw")

# ── Item manifest (mirrors arena_chains.lua CHAIN_DATA) ──────────────────

CHAINS = {
    "ch": {
        "name": "Chill",
        "color_hint": "icy blue and cyan tones, cool colors",
        "items": [
            "Ice Block", "Ice Cubes", "Bucket of Ice",
            "Fridge I", "Fridge II", "Fridge III", "Fridge IV",
            "Fridge V", "Fridge VI", "Fridge VII",
        ],
    },
    "cu": {
        "name": "Cupboard",
        "color_hint": "warm orange and brown wooden tones",
        "items": [
            "Bin", "Utensil Bin", "Tackle Box",
            "Cupboard I", "Cupboard II", "Cupboard III",
            "Cupboard IV", "Cupboard V", "Cupboard VI",
        ],
    },
    "he": {
        "name": "Heating",
        "color_hint": "red and orange metallic tones, warm fire colors",
        "items": [
            "Heating Element", "Knob", "Plunger",
            "Toaster I", "Toaster II", "Toaster III", "Toaster IV",
            "Toaster V", "Toaster VI", "Toaster VII",
        ],
    },
    "bl": {
        "name": "Blending",
        "color_hint": "purple and violet metallic tones",
        "items": [
            "Sieve", "Chasen", "Steel Whisk",
            "Blender I", "Blender II", "Blender III", "Blender IV",
            "Blender V", "Blender VI", "Blender VII",
        ],
    },
    "ki": {
        "name": "Kitchenware",
        "color_hint": "bright green with silver metal accents",
        "items": [
            "Kitchen Knife", "Tenderizer", "Spatula", "Tongs",
            "Ladle", "Sauce Pan", "Pot",
        ],
    },
    "ta": {
        "name": "Tableware",
        "color_hint": "blue ceramic and porcelain tones",
        "items": [
            "Napkin", "Spoon", "Fork", "Butter Knife",
            "Plate", "Cup", "Carafe",
        ],
    },
    "me": {
        "name": "Meat",
        "color_hint": "dark red and brown cooked meat colors",
        "items": [
            "Smoked Meat", "Sausage", "Meatballs", "BBQ Wings", "Nuggets",
            "Drum Stick", "Steak", "Schnitzel", "Schweinhaxe", "Ham",
            "Spare Ribs", "Roast Turkey",
        ],
    },
    "da": {
        "name": "Dairy",
        "color_hint": "golden yellow and cream dairy colors",
        "items": [
            "Egg", "Sunny Side Up", "Scrambled Eggs", "Glass of Milk",
            "Milk Bottle", "Farmer's Can", "Sour Cream", "Soft Cheese",
            "Mozzarella", "Braided Cheese", "Aged Cheddar", "Cheese Wheel",
        ],
    },
    "ba": {
        "name": "Bakery",
        "color_hint": "warm tan and golden brown baked goods colors",
        "items": [
            "Wheat Flour", "Flour Bag", "Bread Slice", "Pretzel",
            "Croissant", "Bagel", "Loaf of Bread", "Ciabatta",
            "Challah", "Mouse Loaf",
        ],
    },
    "de": {
        "name": "Desert",
        "color_hint": "pink and chocolate dessert colors, sweet pastels",
        "items": [
            "Brown Sugar", "Sugar Cubes", "Chocolate", "Truffles",
            "Doughnut", "Eclair", "Strudel", "Cupcake",
            "Pie", "Devil Cake Piece", "Tiramisu", "Creme Brulee",
        ],
    },
    "so": {
        "name": "Soups",
        "color_hint": "warm olive green and earthy soup colors",
        "items": [
            "Noodle Soup", "Clam Chowder", "Gumbo",
            "Onion Soup", "Chili", "Strawberry Soup",
        ],
    },
    "be": {
        "name": "Beverages",
        "color_hint": "teal and refreshing cool beverage colors",
        "items": [
            "Glass of Water", "Cup of Tea", "Coffee",
            "Orange Juice", "Lemonade", "Merge Cola",
        ],
    },
}

NEGATIVE_PROMPT = (
    "text, letters, words, numbers, UI, frame, border, multiple objects, "
    "blurry, low quality, realistic photograph, photorealistic, human, person, hand, fingers, "
    "watermark, signature, complex background, noisy, grainy, dark, gritty"
)

# Explicit descriptions for ambiguous item names.
# The model is not clever with context, so we spell out exactly what each item is.
ITEM_OVERRIDES = {
    # Meat chain — clarify these are FOOD items
    "BBQ Wings": "plate of barbecue chicken wings, fried chicken food",
    "Drum Stick": "fried chicken drumstick leg, chicken food",
    "Nuggets": "plate of golden chicken nuggets, fried chicken food",
    "Schweinhaxe": "German roasted pork knuckle on a plate, cooked meat food",
    "Spare Ribs": "rack of barbecue spare ribs, cooked pork ribs food",
    "Smoked Meat": "piece of smoked cured meat, deli food",
    # Dairy chain
    "Sunny Side Up": "sunny side up fried egg on a plate, breakfast food",
    "Farmer's Can": "metal milk churn can, dairy farming container",
    "Braided Cheese": "braided string cheese, dairy food",
    # Bakery chain
    "Mouse Loaf": "decorative mouse-shaped bread loaf, cute bakery food",
    "Challah": "braided challah bread loaf, jewish bakery food",
    # Heating chain
    "Heating Element": "red-hot electric heating coil element, kitchen appliance part",
    "Knob": "stove temperature dial knob, kitchen appliance part",
    "Plunger": "coffee press plunger, kitchen tool",
    # Blending chain
    "Chasen": "Japanese bamboo matcha whisk tool, tea ceremony utensil",
    "Sieve": "metal kitchen flour sieve strainer, cooking tool",
    # Chill chain
    "Ice Block": "single block of blue ice, frozen cube",
    # Cupboard chain
    "Bin": "small wooden storage bin box, kitchen container",
    "Utensil Bin": "wooden utensil holder bin with spoons, kitchen organizer",
    "Tackle Box": "multi-compartment storage tackle box, organizer container",
    # Soups chain
    "Gumbo": "bowl of thick gumbo stew soup, cajun food",
    "Chili": "bowl of chili con carne stew, spicy food",
    # Beverages chain
    "Merge Cola": "can of cola soda drink, fizzy beverage",
    # Desert chain
    "Devil Cake Piece": "slice of dark chocolate devil's food cake, dessert",
    "Truffles": "chocolate truffles candy, sweet dessert food",
    "Brown Sugar": "pile of brown sugar, baking ingredient",
}

# ── ComfyUI workflow template ────────────────────────────────────────────

def build_workflow(positive_prompt, seed, filename_prefix):
    """FLUX.1 Dev GGUF workflow. No negative prompt — FLUX uses guidance instead."""
    return {
        # UNET (FLUX GGUF)
        "1": {
            "class_type": "UnetLoaderGGUF",
            "inputs": {
                "unet_name": "flux1-dev-Q5_K_S.gguf",
            },
        },
        # Dual CLIP (CLIP-L + T5XXL for FLUX)
        "2": {
            "class_type": "DualCLIPLoader",
            "inputs": {
                "clip_name1": "clip_l.safetensors",
                "clip_name2": "t5xxl_fp8_e4m3fn.safetensors",
                "type": "flux",
            },
        },
        # Positive prompt encoding
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": positive_prompt},
        },
        # Empty conditioning (FLUX needs this for KSampler negative slot)
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": ""},
        },
        # FLUX guidance (replaces CFG — typical 3.5 for Dev)
        "5": {
            "class_type": "FluxGuidance",
            "inputs": {
                "conditioning": ["3", 0],
                "guidance": 3.5,
            },
        },
        # Latent image
        "6": {
            "class_type": "EmptySD3LatentImage",
            "inputs": {"batch_size": 1, "height": 1024, "width": 1024},
        },
        # KSampler — cfg=1 (guidance handled by FluxGuidance node)
        "7": {
            "class_type": "KSampler",
            "inputs": {
                "cfg": 1.0,
                "denoise": 1.0,
                "latent_image": ["6", 0],
                "model": ["1", 0],
                "positive": ["5", 0],
                "negative": ["4", 0],
                "sampler_name": "euler",
                "scheduler": "simple",
                "seed": seed,
                "steps": 28,
            },
        },
        # FLUX VAE
        "8": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "ae.safetensors"},
        },
        # Decode
        "9": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["7", 0], "vae": ["8", 0]},
        },
        # Save
        "10": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": filename_prefix, "images": ["9", 0]},
        },
    }


def build_prompt(item_name, color_hint):
    desc = ITEM_OVERRIDES.get(item_name, item_name)
    return (
        f"A single {desc} drawn as a flat cartoon game icon. "
        f"Simple 2D vector art style with thick black outlines, "
        f"flat cel-shaded colors with minimal gradients, round soft shapes. "
        f"The color palette uses {color_hint}. "
        f"Centered on a pure white background with no shadows. "
        f"Mobile puzzle game art style, like a merge game icon. "
        f"No text, no labels, no face or eyes on the object."
    )


# ── ComfyUI API helpers ──────────────────────────────────────────────────

def check_server():
    try:
        urllib.request.urlopen(f"{SERVER}/system_stats", timeout=5)
        return True
    except Exception:
        return False


def queue_prompt(workflow):
    prompt_id = str(uuid.uuid4())
    payload = json.dumps({"prompt": workflow, "prompt_id": prompt_id}).encode()
    req = urllib.request.Request(f"{SERVER}/prompt", data=payload,
                                headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    if result.get("node_errors"):
        raise RuntimeError(f"Workflow errors: {result['node_errors']}")
    return prompt_id


def poll_history(prompt_id, timeout=600):
    start = time.time()
    while time.time() - start < timeout:
        try:
            url = f"{SERVER}/history/{prompt_id}"
            resp = urllib.request.urlopen(url)
            data = json.loads(resp.read())
            if prompt_id in data:
                return data[prompt_id]
        except Exception:
            pass
        time.sleep(1)
    raise TimeoutError(f"Generation timed out after {timeout}s")


def download_image(filename, subfolder, folder_type):
    params = urllib.parse.urlencode({
        "filename": filename, "subfolder": subfolder, "type": folder_type,
    })
    url = f"{SERVER}/view?{params}"
    resp = urllib.request.urlopen(url)
    return resp.read()


# ── Generation logic ─────────────────────────────────────────────────────

def generate_one(chain_id, level, item_name, color_hint, dry_run=False):
    """Generate a single icon. Returns output path or None."""
    file_key = f"{chain_id}_{level}"
    out_path = os.path.join(OUTPUT_DIR, f"{file_key}.png")

    positive = build_prompt(item_name, color_hint)

    if dry_run:
        print(f"  [{file_key}] {item_name}")
        print(f"    Prompt: {positive[:100]}...")
        return None

    seed = random.randint(0, 2**32 - 1)
    workflow = build_workflow(positive, seed, f"icon_{file_key}")

    prompt_id = queue_prompt(workflow)
    history = poll_history(prompt_id)

    # Find the SaveImage output (node "9")
    outputs = history.get("outputs", {})
    save_output = outputs.get("10", {})
    images = save_output.get("images", [])
    if not images:
        print(f"  WARNING: No images in output for {file_key}")
        return None

    img_info = images[0]
    img_data = download_image(img_info["filename"], img_info.get("subfolder", ""),
                              img_info.get("type", "output"))

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(img_data)

    return out_path


def build_manifest(chain_filter=None, item_filter=None):
    """Build list of (chain_id, level, item_name, color_hint) tuples."""
    manifest = []
    for cid, chain in CHAINS.items():
        if chain_filter and cid != chain_filter.lower():
            continue
        for level, item_name in enumerate(chain["items"], start=1):
            key = f"{cid}_{level}"
            if item_filter and key != item_filter.lower():
                continue
            manifest.append((cid, level, item_name, chain["color_hint"]))
    return manifest


def main():
    parser = argparse.ArgumentParser(description="Generate Merge Arena icons via ComfyUI")
    parser.add_argument("--chain", help="Generate only this chain (e.g. Me, Ch)")
    parser.add_argument("--item", help="Generate single item (e.g. me_3)")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts only")
    parser.add_argument("--no-skip", action="store_true", help="Regenerate existing files")
    args = parser.parse_args()

    manifest = build_manifest(args.chain, args.item)
    if not manifest:
        print("No items match the filter.")
        sys.exit(1)

    if not args.dry_run:
        if not check_server():
            print("ERROR: ComfyUI not reachable at", SERVER)
            print("Start it with: cd ~/ComfyUI && source venv/bin/activate && python main.py --lowvram")
            sys.exit(1)

    skip_existing = not args.no_skip
    total = len(manifest)
    generated = 0
    skipped = 0

    print(f"Generating {total} icons...")
    if args.dry_run:
        print("(DRY RUN - no images will be generated)\n")

    for i, (cid, level, name, hint) in enumerate(manifest, start=1):
        out_path = os.path.join(OUTPUT_DIR, f"{cid}_{level}.png")

        if skip_existing and os.path.exists(out_path) and not args.dry_run:
            skipped += 1
            print(f"  [{i}/{total}] {cid}_{level} ({name}) -- SKIP (exists)")
            continue

        print(f"  [{i}/{total}] {cid}_{level} ({name})", end="")
        if not args.dry_run:
            print(" ... ", end="", flush=True)

        t0 = time.time()
        try:
            result = generate_one(cid, level, name, hint, dry_run=args.dry_run)
            if result:
                elapsed = time.time() - t0
                print(f"OK ({elapsed:.1f}s)")
                generated += 1
            elif not args.dry_run:
                print("FAILED")
        except Exception as e:
            print(f"ERROR: {e}")

    print(f"\nDone. Generated: {generated}, Skipped: {skipped}, Total: {total}")


if __name__ == "__main__":
    main()
