from flask import Blueprint, render_template, request
from models.caesar import caesar_encrypt, caesar_decrypt
from models.substitution import substitution_encrypt, substitution_decrypt
from models.affine import affine_encrypt, affine_decrypt
from models.vigenere import vigenere_encrypt, vigenere_decrypt
from models.hill import hill_encrypt, hill_decrypt
from models.permutation import permutation_encrypt, permutation_decrypt
from models.des import des_encrypt, des_decrypt
from models.rsa import rsa_encrypt, rsa_decrypt
from models.md5 import md5_encrypt, md5_decrypt
from models.sha import sha_encrypt, sha_decrypt
from models.aes import aes_encrypt, aes_decrypt

text_bp = Blueprint("text", __name__, template_folder="../views")

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


@text_bp.route("/", methods=["GET", "POST"], strict_slashes=False)
def text_view():
    result = ""
    error = ""
    if request.method == "POST":
        text = request.form.get("text", "").strip()
        algo = request.form.get("algorithm")
        key = request.form.get("key", "").strip()
        m = request.form.get("m", "").strip()
        action = request.form.get("action")

        try:
            # --- Validate input chung ---
            if not text:
                raise ValueError("Vui lòng nhập nội dung văn bản.")
            if algo not in algorithms:
                raise ValueError("Thuật toán không hợp lệ.")
            if action not in ["encrypt", "decrypt"]:
                raise ValueError("Hành động không hợp lệ (encrypt/decrypt).")

            # --- Xử lý riêng theo thuật toán ---
            if algo == "rsa":
                # RSA cần 2 khóa (public/private)
                key_parts = key.split(",")
                if len(key_parts) != 2:
                    raise ValueError("RSA cần 2 khóa, ví dụ: '7,33'")
                n, exp = map(int, key_parts)
                func = algorithms[algo][action]
                result = func(text, (n, exp))

            elif algo == "affine":
                # affine cần a,b,m (m là độ dài bảng chữ cái, ví dụ 26)
                key_parts = key.split(",")
                if len(key_parts) != 2:
                    raise ValueError("Affine cần khóa dạng 'a,b'")
                a, b = map(int, key_parts)
                mod = int(m) if m else 26
                func = algorithms[algo][action]
                result = func(text, a, b, mod)

            elif algo == "hill":
                # hill cần ma trận khóa, nhập theo hàng ví dụ "3,3;2,5"
                rows = key.split(";")
                matrix = [list(map(int, r.split(","))) for r in rows]
                func = algorithms[algo][action]
                result = func(text, matrix)

            elif algo == "des":
                # DES yêu cầu khóa 8 byte
                if len(key) != 8:
                    raise ValueError("Khóa DES phải dài đúng 8 ký tự.")
                func = algorithms[algo][action]
                result = func(text, key)

            else:
                # Các thuật toán đơn giản
                func = algorithms[algo][action]
                result = func(text, key, m)

        except Exception as e:
            error = str(e)

    return render_template("text.html", result=result, error=error)
