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


#include "baton.hpp"
#include "node.hpp"
#include "router.hpp"
#include "version.hpp"

namespace orc {

void Node::Run(const asio::ip::address &bind, uint16_t port, const std::string &key, const std::string &chain, const std::string &params) {
    Router router;

    router(http::verb::post, "/", [&](Request request) -> task<Response> {
        const auto offer(request.body());
        // XXX: look up fingerprint
        static int fingerprint_(0);
        std::string fingerprint(std::to_string(fingerprint_++));

        // XXX: this is a fingerprint I used once in a curl command for testing and now spams the server
        if (offer.find("DB:7F:E8:DC:D7:D2:70:56:49:66:71:F7:A0:D9:1E:36:40:53:ED:EB:39:59:0A:D1:35:DA:88:C5:E9:A1:C5:78") != std::string::npos)
            co_return Respond(request, http::status::ok, "text/plain", "v=");

        const auto server(Find(fingerprint));
        auto answer(co_await server->Respond(offer, ice_));

        Log() << std::endl;
        Log() << "^^^^^^^^^^^^^^^^" << std::endl;
        Log() << offer << std::endl;
        Log() << "================" << std::endl;
        Log() << answer << std::endl;
        Log() << "vvvvvvvvvvvvvvvv" << std::endl;
        Log() << std::endl;

        co_return Respond(request, http::status::ok, "text/plain", std::move(answer));
    });

    router(http::verb::get, "/version.txt", [&](Request request) -> task<Response> {
        co_return Respond(request, http::status::ok, "text/plain", std::string(VersionData, VersionSize));
    });

    router.Run(bind, port, key, chain, params);
    Thread().join();
}

}
