/* Orchid - WebRTC P2P VPN Market (on Ethereum)
 * Copyright (C) 2017-2020  The Orchid Authors
*/

/* GNU Affero General Public License, Version 3 {{{ */
/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */


#ifndef ORCHID_CRYPTO_HPP
#define ORCHID_CRYPTO_HPP

#include <secp256k1.h>

#include "buffer.hpp"

#define _crycall(code) do { \
    orc_assert((code) == 0); \
} while (false)

namespace orc {

void Random(uint8_t *data, size_t size);

template <size_t Size_>
Brick<Size_> Random() {
    Brick<Size_> value;
    Random(value.data(), value.size());
    return value;
}

Brick<32> HashK(const Buffer &data);
inline Brick<32> HashK(const std::string &data) {
    return HashK(Subset(data)); }

Brick<32> Hash2(const Buffer &data);
inline Brick<32> Hash2(const std::string &data) {
    return Hash2(Subset(data)); }

Brick<20> Hash1(const Buffer &data);

Brick<20> HashR(const Buffer &data);
inline Brick<20> HashR(const std::string &data) {
    return HashR(Subset(data)); }

Brick<16> Hash5(const Buffer &data);
inline Brick<16> Hash5(const std::string &data) {
    return Hash5(Subset(data)); }

template <auto Hash_>
auto Auth(const Region &secret, const std::string &data) {
    Brick<64> inner; memset(inner.data(), 0x36, inner.size());
    Brick<64> outer; memset(outer.data(), 0x5c, outer.size());

    orc_assert(secret.size() <= 64);
    for (size_t i(0), e(secret.size()); i != e; ++i) {
        inner[i] ^= secret[i];
        outer[i] ^= secret[i];
    }

    return Hash_(Tie(outer, Hash_(Tie(inner, data))));
}

struct Signature {
    Brick<32> r_;
    Brick<32> s_;
    uint8_t v_;

    Signature(const Brick<32> &r, const Brick<32> &s, uint8_t v);
    Signature(const Brick<64> &data, int v);
    Signature(const Brick<65> &data);

    operator Brick<65>() const {
        auto [external] = Take<Brick<65>>(Tie(r_, s_, Number<uint8_t>(v_)));
        return external;
    }
};

using Secret = Brick<32>;
typedef secp256k1_pubkey Key;
Key Derive(const Secret &secret);

Key ToKey(const Region &data);

Brick<65> ToUncompressed(const Key &key);
Brick<33> ToCompressed(const Key &key);

Signature Sign(const Secret &secret, const Brick<32> &data);
Key Recover(const Brick<32> &data, const Signature &signature);

inline Key Recover(const Brick<32> &data, uint8_t v, const Brick<32> &r, const Brick<32> &s) {
    orc_assert(v >= 27);
    return Recover(data, Signature(r, s, v - 27));
}

Beam Object(int nid);
Beam Object(const char *ln);

size_t Length(Window &window);

}

#endif//ORCHID_CRYPTO_HPP
