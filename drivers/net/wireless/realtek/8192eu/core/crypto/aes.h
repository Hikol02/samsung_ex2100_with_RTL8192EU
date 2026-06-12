/*
 * AES functions
 * Copyright (c) 2003-2006, Jouni Malinen <j@w1.fi>
 *
 * This software may be distributed under the terms of the BSD license.
 * See README for more details.
 */


#ifndef _RTW_AES_RENAME_H_
#define _RTW_AES_RENAME_H_

#define aes_encrypt rtw_crypto_aes_encrypt
#define aes_decrypt rtw_crypto_aes_decrypt

#endif

#ifndef AES_H
#define AES_H

#define AES_BLOCK_SIZE 16

void * aes_encrypt_init(const u8 *key, size_t len);
int aes_encrypt(void *ctx, const u8 *plain, u8 *crypt);
void aes_encrypt_deinit(void *ctx);
void * aes_decrypt_init(const u8 *key, size_t len);
int aes_decrypt(void *ctx, const u8 *crypt, u8 *plain);
void aes_decrypt_deinit(void *ctx);

#endif /* AES_H */
