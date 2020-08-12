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


#ifndef ORCHID_MAYBE_HPP
#define ORCHID_MAYBE_HPP

#include <variant>

namespace orc {

// XXX: this should not require the variant tag

template <typename Type_>
class Maybe :
    public std::variant<std::exception_ptr, Type_>
{
  public:
    using std::variant<std::exception_ptr, Type_>::variant;

    void operator()(const std::exception_ptr &error) noexcept {
        this->~Maybe();
        new (this) Maybe(std::in_place_index_t<0>(), error);
    }

    Maybe &operator =(Type_ &&value) noexcept {
        this->~Maybe();
        new (this) Maybe(std::in_place_index_t<1>(), std::move(value));
        return *this;
    }

    template <typename Code_, typename std::enable_if_t<std::is_invocable_v<Code_ &&>>>
    void operator()(Code_ &&code) noexcept {
        try {
            operator =(std::forward<Code_>(code)());
        } catch (...) {
            operator ()(std::current_exception());
        }
    }

    Type_ operator *() && {
        if (const auto error = std::get_if<0>(this))
            std::rethrow_exception(*error);
        else if (auto value = std::get_if<1>(this))
            return std::move(*value);
        else orc_assert(false);
    }
};

template <>
class Maybe<void> {
  private:
    std::exception_ptr error_;

  public:
    Maybe() = default;

    Maybe(const std::exception_ptr &error) noexcept :
        error_(error)
    {
    }

    void operator()(const std::exception_ptr &error) noexcept {
        error_ = error;
    }

    void operator()() noexcept {
        error_ = nullptr;
    }

    template <typename Code_, typename std::enable_if_t<std::is_invocable_v<Code_ &&>>>
    void operator()(Code_ &&code) noexcept {
        try {
            std::forward<Code_>(code)();
            operator ()();
        } catch (...) {
            operator ()(std::current_exception());
        }
    }

    void operator *() && {
        if (error_ != nullptr)
            std::rethrow_exception(error_);
    }
};

}

#endif//ORCHID_MAYBE_HPP
