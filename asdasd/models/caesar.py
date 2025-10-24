def caesar_encrypt(text, key, m):
    shift = int(key)
    result = ""
    for ch in text:
        result += chr((ord(ch) + shift) % 256)  
    return result

def caesar_decrypt(text, key, m):
    return caesar_encrypt(text, -int(key), m)
