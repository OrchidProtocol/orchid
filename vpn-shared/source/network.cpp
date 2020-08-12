/* Orchid - WebRTC P2P VPN Market (on Ethereum)
 * Copyright (C) 2017-2019  The Orchid Authors
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


#include <openssl/obj_mac.h>

#include "chainlink.hpp"
#include "client.hpp"
#include "endpoint.hpp"
#include "fiat.hpp"
#include "local.hpp"
#include "market.hpp"
#include "network.hpp"
#include "sleep.hpp"
#include "uniswap.hpp"
#include "updater.hpp"

namespace orc {

Network::Network(const std::string &rpc, Address directory, Address location, const S<Origin> &origin) :
    locator_(Locator::Parse(rpc)),
    directory_(std::move(directory)),
    location_(std::move(location)),
    market_(Make<Market>(5*60*1000, origin, Wait(UniswapFiat(5*60*1000, {origin, locator_})))),
    oracle_(Wait(Update(5*60*1000, [endpoint = Endpoint(origin, locator_)]() -> task<Float> { try {
        static const Float Ten5("100000");
        const auto oracle(co_await Chainlink(endpoint, "0xa6781b4a1eCFB388905e88807c7441e56D887745", Ten5));
        // XXX: our Chainlink aggregation can have its answer forged by either Chainlink swapping the oracle set
        //      or by Orchid modifying the backend from our dashboard that Chainlink pays its oracles to consult
        co_return oracle > 0.10 ? 0.10 : oracle;
    } orc_catch({
        // XXX: our Chainlink aggregation has a remote killswitch in it left by Chainlink, so we need a fallback
        // XXX: figure out if there is a better way to detect this condition vs. another random JSON/RPC failure
        co_return 0.06;
    }) }, "Chainlink")))
{
    generator_.seed(boost::random::random_device()());
}

task<Client *> Network::Select(BufferSunk &sunk, const S<Origin> &origin, const std::string &name, const Address &provider, const Address &lottery, const uint256_t &chain, const Secret &secret, const Address &funder, const char *justin) {
    Endpoint endpoint(origin, locator_);

    // XXX: this adjustment is suboptimal; it seems to help?
    //const auto latest(co_await endpoint.Latest() - 1);
    //const auto block(co_await endpoint.Header(latest));
    // XXX: Cloudflare's servers are almost entirely broken
    static const std::string latest("latest");

    typedef std::tuple<Address, std::string, U<rtc::SSLFingerprint>> Descriptor;
    auto [address, url, fingerprint] = co_await [&]() -> task<Descriptor> {
        //co_return Descriptor{"0x2b1ce95573ec1b927a90cb488db113b40eeb064a", "https://local.saurik.com:8084/", rtc::SSLFingerprint::CreateUniqueFromRfc4572("sha-256", "A9:E2:06:F8:42:C2:2A:CC:0D:07:3C:E4:2B:8A:FD:26:DD:85:8F:04:E0:2E:90:74:89:93:E2:A5:58:53:85:15")};

        // XXX: parse the / out of name (but probably punt this to the frontend)
        Beam argument;
        const auto curator(co_await endpoint.Resolve(latest, name));

        const auto address(co_await [&]() -> task<Address> {
            if (provider != Address(0))
                co_return provider;

            static const Selector<std::tuple<Address, uint128_t>, uint128_t> pick_("pick");
            const auto [address, delay] = co_await pick_.Call(endpoint, latest, directory_, 90000, generator_());
            orc_assert(delay >= 90*24*60*60);
            co_return address;
        }());

        static const Selector<uint128_t, Address, Bytes> good_("good");
        static const Selector<std::tuple<uint256_t, Bytes, Bytes, Bytes>, Address> look_("look");

        const auto [good, look] = *co_await Parallel(
            good_.Call(endpoint, latest, curator, 90000, address, argument),
            look_.Call(endpoint, latest, location_, 90000, address));
        const auto &[set, url, tls, gpg] = look;

        orc_assert(good != 0);
        orc_assert(set != 0);

        Window window(tls);
        orc_assert(window.Take() == 0x06);
        window.Skip(Length(window));
        const Beam fingerprint(window);

        static const std::map<Beam, std::string> algorithms_({
            {Object(NID_md2), "md2"},
            {Object(NID_md5), "md5"},
            {Object(NID_sha1), "sha-1"},
            {Object(NID_sha224), "sha-224"},
            {Object(NID_sha256), "sha-256"},
            {Object(NID_sha384), "sha-384"},
            {Object(NID_sha512), "sha-512"},
        });

        const auto algorithm(algorithms_.find(Window(tls).Take(tls.size() - fingerprint.size())));
        orc_assert(algorithm != algorithms_.end());
        co_return Descriptor{address, url.str(), std::make_unique<rtc::SSLFingerprint>(algorithm->second, fingerprint.data(), fingerprint.size())};
    }();

    static const Selector<std::tuple<uint128_t, uint128_t, uint256_t, Address, Bytes32, Bytes>, Address, Address> look_("look");
    const auto [amount, escrow, unlock, seller, codehash, shared] = co_await look_.Call(endpoint, latest, lottery, 90000, funder, Address(Commonize(secret)));
    orc_assert(unlock == 0);

    auto &client(sunk.Wire<Client>(
        std::move(url), std::move(fingerprint),
        std::move(endpoint), market_, oracle_,
        lottery, chain,
        secret, funder,
        seller, std::min(amount, escrow / 2),
        justin
    ));

    co_await client.Open(origin);
    co_return &client;
}

}
