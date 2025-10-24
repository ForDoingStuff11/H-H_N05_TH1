from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
import base64

# Hàm sinh cặp khóa công khai / bí mật
def generate_rsa_keys():
    key = RSA.generate(2048)
    private_key = key.export_key().decode('utf-8')
    public_key = key.publickey().export_key().decode('utf-8')
    return public_key, private_key


# Mã hóa bằng khóa công khai
def rsa_encrypt(plaintext, public_key_str, _=None):
    public_key = RSA.import_key(public_key_str)
    cipher = PKCS1_OAEP.new(public_key)
    encrypted = cipher.encrypt(plaintext.encode('utf-8'))
    return base64.b64encode(encrypted).decode('utf-8')


# Giải mã bằng khóa bí mật
def rsa_decrypt(ciphertext, private_key_str, _=None):
    private_key = RSA.import_key(private_key_str)
    cipher = PKCS1_OAEP.new(private_key)
    decrypted = cipher.decrypt(base64.b64decode(ciphertext))
    return decrypted.decode('utf-8')
