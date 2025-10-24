import os
import random
import string
from flask import Blueprint, render_template, request, send_file, flash

# Import các thuật toán
from models.caesar import caesar_encrypt, caesar_decrypt
from models.substitution import substitution_encrypt, substitution_decrypt
from models.affine import affine_encrypt, affine_decrypt
from models.vigenere import vigenere_encrypt, vigenere_decrypt
from models.hill import hill_encrypt, hill_decrypt
from models.permutation import permutation_encrypt, permutation_decrypt
from models.des import des_encrypt, des_decrypt
from models.rsa import rsa_encrypt, rsa_decrypt, generate_rsa_keys
from models.md5 import md5_encrypt, md5_decrypt
from models.sha import sha_encrypt, sha_decrypt
from models.aes import aes_encrypt, aes_decrypt


file_bp = Blueprint("file", __name__, template_folder="../views")

algorithms = {
    "caesar": {"encrypt": caesar_encrypt, "decrypt": caesar_decrypt},
    "substitution": {"encrypt": substitution_encrypt, "decrypt": substitution_decrypt},
    "affine": {"encrypt": affine_encrypt, "decrypt": affine_decrypt},
    "vigenere": {"encrypt": vigenere_encrypt, "decrypt": vigenere_decrypt},
    "hill": {"encrypt": hill_encrypt, "decrypt": hill_decrypt},
    "permutation": {"encrypt": permutation_encrypt, "decrypt": permutation_decrypt},
    "des": {"encrypt": des_encrypt, "decrypt": des_decrypt},
    "rsa": {"encrypt": rsa_encrypt, "decrypt": rsa_decrypt},
    "aes": {"encrypt": aes_encrypt, "decrypt": aes_decrypt},
    "md5": {"encrypt": md5_encrypt, "decrypt": md5_decrypt},
    "sha": {"encrypt": sha_encrypt, "decrypt": sha_decrypt},
}

# Các nhóm thuật toán
TEXT_BASED = {"caesar", "substitution", "affine", "vigenere", "hill", "permutation"}
BINARY_BASED = {"aes", "des", "rsa", "md5", "sha"}
REQUIRES_M = {"affine", "hill", "permutation"}
NEEDS_MATRIX = {"hill"}
HAS_PUBLIC_PRIVATE_KEYS = {"rsa"}
NO_KEY_NEEDED = set()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def random_string(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))


@file_bp.route("/", methods=["GET", "POST"], strict_slashes=False)
def file_view():
    if request.method == "POST":
        file = request.files.get("file")
        algo = request.form.get("algorithm")
        key = request.form.get("key", "").strip()
        m = request.form.get("m", "").strip()
        action = request.form.get("action")
        delete_original = request.form.get("delete_original")
        matrix_str = request.form.get("matrix", "").strip()

        if not file:
            flash("Vui lòng chọn file để mã hóa/giải mã.", "warning")
            return render_template("file.html")

        if algo not in algorithms:
            flash("Thuật toán không hợp lệ.", "danger")
            return render_template("file.html")

        # --- Trường hợp RSA ---
        if algo in HAS_PUBLIC_PRIVATE_KEYS and action == "encrypt":
            pub_key, priv_key = generate_rsa_keys()
            with open(os.path.join(UPLOAD_FOLDER, "public.pem"), "wb") as f:
                f.write(pub_key.save_pkcs1())
            with open(os.path.join(UPLOAD_FOLDER, "private.pem"), "wb") as f:
                f.write(priv_key.save_pkcs1())
            flash("Đã sinh cặp khóa RSA (public.pem & private.pem)", "info")

        # --- Kiểm tra các input cần thiết ---
        if algo not in NO_KEY_NEEDED and not key and algo not in HAS_PUBLIC_PRIVATE_KEYS:
            flash("Vui lòng nhập key hoặc dùng Auto Generate.", "warning")
            return render_template("file.html")

        if algo in REQUIRES_M and not m:
            flash("Thuật toán này yêu cầu thêm giá trị m.", "warning")
            return render_template("file.html")

        if algo in NEEDS_MATRIX and not matrix_str and action == "encrypt":
            flash("Vui lòng nhập ma trận khóa Hill (vd: 3 3 2 5).", "warning")
            return render_template("file.html")

        # --- Đọc file (phân loại theo loại thuật toán) ---
        filename = os.path.join(UPLOAD_FOLDER, file.filename)
        file.save(filename)

        if algo in TEXT_BASED:
            try:
                with open(filename, "r", encoding="utf-8") as f:
                    data = f.read()
            except UnicodeDecodeError:
                flash("File không phải là văn bản UTF-8.", "danger")
                return render_template("file.html")
        else:  # BINARY_BASED
            with open(filename, "rb") as f:
                data = f.read()

        func = algorithms[algo][action]

        try:
            if algo in HAS_PUBLIC_PRIVATE_KEYS:
                if action == "encrypt":
                    result = func(data, os.path.join(UPLOAD_FOLDER, "public.pem"))
                else:
                    result = func(data, os.path.join(UPLOAD_FOLDER, "private.pem"))
            elif algo in NEEDS_MATRIX:
                result = func(data, matrix_str, m)
            elif algo in REQUIRES_M:
                result = func(data, key, m)
            else:
                result = func(data, key)
        except Exception as e:
            flash(f"Lỗi xử lý ({algo}): {e}", "danger")
            return render_template("file.html")

        # --- Ghi file kết quả ---
        result_filename = os.path.join(
            UPLOAD_FOLDER,
            file.filename + (".enc" if action == "encrypt" else ".dec"),
        )

        if isinstance(result, bytes):  # Nếu kết quả là bytes (AES, DES, RSA)
            with open(result_filename, "wb") as f:
                f.write(result)
        else:  # Nếu là string (Caesar, Vigenere, ...)
            with open(result_filename, "w", encoding="utf-8") as f:
                f.write(result)

        if delete_original:
            try:
                os.remove(filename)
            except:
                pass

        return send_file(result_filename, as_attachment=True)

    return render_template("file.html")
