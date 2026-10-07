import base64
import hashlib
import hmac
import os
from functools import lru_cache
from typing import Iterable

from dotenv import load_dotenv
from sqlalchemy.types import Text, TypeDecorator

load_dotenv()

SM4_PREFIX = "sm4:v1:"
_BLOCK_SIZE = 16

_SBOX = [
    0xD6, 0x90, 0xE9, 0xFE, 0xCC, 0xE1, 0x3D, 0xB7, 0x16, 0xB6, 0x14, 0xC2, 0x28, 0xFB, 0x2C, 0x05,
    0x2B, 0x67, 0x9A, 0x76, 0x2A, 0xBE, 0x04, 0xC3, 0xAA, 0x44, 0x13, 0x26, 0x49, 0x86, 0x06, 0x99,
    0x9C, 0x42, 0x50, 0xF4, 0x91, 0xEF, 0x98, 0x7A, 0x33, 0x54, 0x0B, 0x43, 0xED, 0xCF, 0xAC, 0x62,
    0xE4, 0xB3, 0x1C, 0xA9, 0xC9, 0x08, 0xE8, 0x95, 0x80, 0xDF, 0x94, 0xFA, 0x75, 0x8F, 0x3F, 0xA6,
    0x47, 0x07, 0xA7, 0xFC, 0xF3, 0x73, 0x17, 0xBA, 0x83, 0x59, 0x3C, 0x19, 0xE6, 0x85, 0x4F, 0xA8,
    0x68, 0x6B, 0x81, 0xB2, 0x71, 0x64, 0xDA, 0x8B, 0xF8, 0xEB, 0x0F, 0x4B, 0x70, 0x56, 0x9D, 0x35,
    0x1E, 0x24, 0x0E, 0x5E, 0x63, 0x58, 0xD1, 0xA2, 0x25, 0x22, 0x7C, 0x3B, 0x01, 0x21, 0x78, 0x87,
    0xD4, 0x00, 0x46, 0x57, 0x9F, 0xD3, 0x27, 0x52, 0x4C, 0x36, 0x02, 0xE7, 0xA0, 0xC4, 0xC8, 0x9E,
    0xEA, 0xBF, 0x8A, 0xD2, 0x40, 0xC7, 0x38, 0xB5, 0xA3, 0xF7, 0xF2, 0xCE, 0xF9, 0x61, 0x15, 0xA1,
    0xE0, 0xAE, 0x5D, 0xA4, 0x9B, 0x34, 0x1A, 0x55, 0xAD, 0x93, 0x32, 0x30, 0xF5, 0x8C, 0xB1, 0xE3,
    0x1D, 0xF6, 0xE2, 0x2E, 0x82, 0x66, 0xCA, 0x60, 0xC0, 0x29, 0x23, 0xAB, 0x0D, 0x53, 0x4E, 0x6F,
    0xD5, 0xDB, 0x37, 0x45, 0xDE, 0xFD, 0x8E, 0x2F, 0x03, 0xFF, 0x6A, 0x72, 0x6D, 0x6C, 0x5B, 0x51,
    0x8D, 0x1B, 0xAF, 0x92, 0xBB, 0xDD, 0xBC, 0x7F, 0x11, 0xD9, 0x5C, 0x41, 0x1F, 0x10, 0x5A, 0xD8,
    0x0A, 0xC1, 0x31, 0x88, 0xA5, 0xCD, 0x7B, 0xBD, 0x2D, 0x74, 0xD0, 0x12, 0xB8, 0xE5, 0xB4, 0xB0,
    0x89, 0x69, 0x97, 0x4A, 0x0C, 0x96, 0x77, 0x7E, 0x65, 0xB9, 0xF1, 0x09, 0xC5, 0x6E, 0xC6, 0x84,
    0x18, 0xF0, 0x7D, 0xEC, 0x3A, 0xDC, 0x4D, 0x20, 0x79, 0xEE, 0x5F, 0x3E, 0xD7, 0xCB, 0x39, 0x48,
]

_FK = [0xA3B1BAC6, 0x56AA3350, 0x677D9197, 0xB27022DC]
_CK = [
    0x00070E15, 0x1C232A31, 0x383F464D, 0x545B6269, 0x70777E85, 0x8C939AA1, 0xA8AFB6BD, 0xC4CBD2D9,
    0xE0E7EEF5, 0xFC030A11, 0x181F262D, 0x343B4249, 0x50575E65, 0x6C737A81, 0x888F969D, 0xA4ABB2B9,
    0xC0C7CED5, 0xDCE3EAF1, 0xF8FF060D, 0x141B2229, 0x30373E45, 0x4C535A61, 0x686F767D, 0x848B9299,
    0xA0A7AEB5, 0xBCC3CAD1, 0xD8DFE6ED, 0xF4FB0209, 0x10171E25, 0x2C333A41, 0x484F565D, 0x646B7279,
]


class EncryptionConfigError(RuntimeError):
    pass


def is_encrypted_sensitive_value(value: str | None) -> bool:
    return isinstance(value, str) and value.startswith(SM4_PREFIX)


def encrypt_sensitive_value(value: str | None) -> str | None:
    if value is None or value == "":
        return value
    text_value = str(value)
    if is_encrypted_sensitive_value(text_value):
        return text_value

    encryption_key, mac_key, _ = _derive_keys()
    iv = os.urandom(_BLOCK_SIZE)
    ciphertext = _sm4_cbc_encrypt(text_value.encode("utf-8"), encryption_key, iv)
    tag = hmac.new(mac_key, iv + ciphertext, hashlib.sha256).digest()[:16]
    payload = _urlsafe_b64encode(iv + ciphertext + tag)
    return f"{SM4_PREFIX}{payload}"


def decrypt_sensitive_value(value: str | None) -> str | None:
    if value is None or value == "":
        return value
    if not is_encrypted_sensitive_value(value):
        return value

    try:
        encryption_key, mac_key, _ = _derive_keys()
        payload = _urlsafe_b64decode(value[len(SM4_PREFIX):])
        if len(payload) < _BLOCK_SIZE * 3 or (len(payload) - 32) % _BLOCK_SIZE != 0:
            return ""

        iv = payload[:_BLOCK_SIZE]
        tag = payload[-16:]
        ciphertext = payload[_BLOCK_SIZE:-16]
        expected_tag = hmac.new(mac_key, iv + ciphertext, hashlib.sha256).digest()[:16]
        if not hmac.compare_digest(tag, expected_tag):
            return ""
        plaintext = _sm4_cbc_decrypt(ciphertext, encryption_key, iv)
        return plaintext.decode("utf-8")
    except Exception:
        return ""


def phone_lookup_hash(phone: str | None) -> str | None:
    if phone is None:
        return None
    _, _, hash_key = _derive_keys()
    return hmac.new(hash_key, phone.strip().encode("utf-8"), hashlib.sha256).hexdigest()


class EncryptedString(TypeDecorator):
    impl = Text
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        return encrypt_sensitive_value(str(value))

    def process_result_value(self, value, dialect):
        return decrypt_sensitive_value(value)


@lru_cache(maxsize=1)
def _derive_keys() -> tuple[bytes, bytes, bytes]:
    raw_key = os.getenv("DATABASE_ENCRYPTION_KEY") or os.getenv("ENCRYPTION_KEY")
    if not raw_key:
        raise EncryptionConfigError(
            "未设置 DATABASE_ENCRYPTION_KEY 或 ENCRYPTION_KEY，无法加密敏感数据库字段。"
        )

    material = raw_key.encode("utf-8")
    decoded_key = _try_decode_base64_key(raw_key)
    if decoded_key:
        material += decoded_key

    encryption_key = hashlib.sha256(b"hospital-sm4-encryption-v1" + material).digest()[:16]
    mac_key = hashlib.sha256(b"hospital-sm4-auth-v1" + material).digest()
    hash_key = hashlib.sha256(b"hospital-phone-lookup-v1" + material).digest()
    return encryption_key, mac_key, hash_key


def _try_decode_base64_key(raw_key: str) -> bytes:
    padded = raw_key + "=" * (-len(raw_key) % 4)
    for decoder in (base64.urlsafe_b64decode, base64.b64decode):
        try:
            decoded = decoder(padded.encode("ascii"))
        except Exception:
            continue
        if decoded:
            return decoded
    return b""


def _urlsafe_b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _urlsafe_b64decode(data: str) -> bytes:
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4))


def _sm4_cbc_encrypt(plaintext: bytes, key: bytes, iv: bytes) -> bytes:
    padded = _pkcs7_pad(plaintext)
    round_keys = _round_keys(key)
    previous = iv
    blocks: list[bytes] = []
    for block in _chunks(padded, _BLOCK_SIZE):
        encrypted = _sm4_block_encrypt(_xor_bytes(block, previous), round_keys)
        blocks.append(encrypted)
        previous = encrypted
    return b"".join(blocks)


def _sm4_cbc_decrypt(ciphertext: bytes, key: bytes, iv: bytes) -> bytes:
    if len(ciphertext) % _BLOCK_SIZE != 0:
        raise ValueError("Invalid SM4 ciphertext length")
    round_keys = list(reversed(_round_keys(key)))
    previous = iv
    blocks: list[bytes] = []
    for block in _chunks(ciphertext, _BLOCK_SIZE):
        decrypted = _xor_bytes(_sm4_block_encrypt(block, round_keys), previous)
        blocks.append(decrypted)
        previous = block
    return _pkcs7_unpad(b"".join(blocks))


def _sm4_block_encrypt(block: bytes, round_keys: list[int]) -> bytes:
    x = [int.from_bytes(block[i:i + 4], "big") for i in range(0, _BLOCK_SIZE, 4)]
    for i in range(32):
        x.append(x[i] ^ _t(x[i + 1] ^ x[i + 2] ^ x[i + 3] ^ round_keys[i]))
    return b"".join(word.to_bytes(4, "big") for word in (x[35], x[34], x[33], x[32]))


def _round_keys(key: bytes) -> list[int]:
    if len(key) != _BLOCK_SIZE:
        raise ValueError("SM4 key must be 16 bytes")
    mk = [int.from_bytes(key[i:i + 4], "big") for i in range(0, _BLOCK_SIZE, 4)]
    k = [mk[i] ^ _FK[i] for i in range(4)]
    round_keys: list[int] = []
    for i in range(32):
        rk = k[i] ^ _t_key(k[i + 1] ^ k[i + 2] ^ k[i + 3] ^ _CK[i])
        rk &= 0xFFFFFFFF
        round_keys.append(rk)
        k.append(rk)
    return round_keys


def _t(value: int) -> int:
    b = _substitute(value)
    return b ^ _rotl(b, 2) ^ _rotl(b, 10) ^ _rotl(b, 18) ^ _rotl(b, 24)


def _t_key(value: int) -> int:
    b = _substitute(value)
    return b ^ _rotl(b, 13) ^ _rotl(b, 23)


def _substitute(value: int) -> int:
    return (
        (_SBOX[(value >> 24) & 0xFF] << 24)
        | (_SBOX[(value >> 16) & 0xFF] << 16)
        | (_SBOX[(value >> 8) & 0xFF] << 8)
        | _SBOX[value & 0xFF]
    )


def _rotl(value: int, bits: int) -> int:
    value &= 0xFFFFFFFF
    return ((value << bits) & 0xFFFFFFFF) | (value >> (32 - bits))


def _pkcs7_pad(data: bytes) -> bytes:
    pad_length = _BLOCK_SIZE - (len(data) % _BLOCK_SIZE)
    return data + bytes([pad_length]) * pad_length


def _pkcs7_unpad(data: bytes) -> bytes:
    if not data:
        raise ValueError("Invalid PKCS7 padding")
    pad_length = data[-1]
    if pad_length < 1 or pad_length > _BLOCK_SIZE:
        raise ValueError("Invalid PKCS7 padding")
    if data[-pad_length:] != bytes([pad_length]) * pad_length:
        raise ValueError("Invalid PKCS7 padding")
    return data[:-pad_length]


def _xor_bytes(left: bytes, right: bytes) -> bytes:
    return bytes(a ^ b for a, b in zip(left, right))


def _chunks(data: bytes, size: int) -> Iterable[bytes]:
    for index in range(0, len(data), size):
        yield data[index:index + size]
