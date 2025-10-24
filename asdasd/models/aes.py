def aes_encrypt(text: str, key: str) -> str:
    from Crypto.Cipher import AES
    from Crypto.Util.Padding import pad
    import base64

    key = key.encode().ljust(16, b'\0')[:16]  # đảm bảo 16 byte
    cipher = AES.new(key, AES.MODE_ECB)
    ct_bytes = cipher.encrypt(pad(text.encode(), AES.block_size))
    return base64.b64encode(ct_bytes).decode()

def aes_decrypt(enc_text: str, key: str) -> str:
    from Crypto.Cipher import AES
    from Crypto.Util.Padding import unpad
    import base64

    key = key.encode().ljust(16, b'\0')[:16]
    cipher = AES.new(key, AES.MODE_ECB)
    try:
        pt = unpad(cipher.decrypt(base64.b64decode(enc_text)), AES.block_size)
        return pt.decode()
    except ValueError:
        return "Decryption error (invalid key or ciphertext)."
