import hashlib

def md5_encrypt(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()

def md5_decrypt(_):
    return "MD5 is a one-way hash function. Decryption not possible."