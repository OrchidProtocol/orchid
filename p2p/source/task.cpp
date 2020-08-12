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


#include <set>

#include "locked.hpp"
#include "task.hpp"

namespace orc {

Locked<std::set<Fiber *>> fibers_;

Fiber::Fiber(const char *name, Fiber *parent) :
    name_(name),
    parent_(parent)
{
    fibers_()->emplace(this);
}

Fiber::~Fiber() {
    fibers_()->erase(this);
}

void Fiber::Report() {
    auto fibers(*fibers_());
#if 0
    for (const auto fiber : fibers)
        if (const auto parent = fiber->parent_)
            fibers.erase(parent);
#endif

    std::cerr << std::endl;
    std::cerr << "^^^^^^^^^^" << std::endl;
    for (const auto fiber : fibers) {
        std::cerr << fiber;
        std::cerr << "/";
        std::cerr << fiber->parent_;
        if (fiber->name_ != nullptr)
            std::cerr << ": " << fiber->name_;
        std::cerr << std::endl;
    }
    std::cerr << "vvvvvvvvvv" << std::endl;
    std::cerr << std::endl;
}

}
