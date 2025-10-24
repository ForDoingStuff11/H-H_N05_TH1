import hashlib

def sha_encrypt(text: str, sha_type: str = "sha256") -> str:
    """
    Hỗ trợ SHA1, SHA256, SHA512
    """
    if sha_type == "sha1":
        return hashlib.sha1(text.encode()).hexdigest()
    elif sha_type == "sha512":
        return hashlib.sha512(text.encode()).hexdigest()
    else:  # mặc định sha256
        return hashlib.sha256(text.encode()).hexdigest()

def sha_decrypt(_):
    return "SHA is a one-way hash function. Decryption not possible."
