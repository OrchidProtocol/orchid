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


#include <cstdio>
#include <future>
#include <string>

#include "crypto.hpp"
#include "jsonrpc.hpp"
#include "buffer.hpp"
#include "local.hpp"

#include "tests.h"

#include <secp256k1.h>
#include <secp256k1_ecdh.h>
#include <secp256k1_recovery.h>

typedef uint8_t byte;

namespace orc
{

	using boost::multiprecision::cpp_int_backend;
	using boost::multiprecision::unsigned_magnitude;
	using boost::multiprecision::unchecked;

	typedef boost::multiprecision::number<cpp_int_backend<160, 160, unsigned_magnitude, unchecked, void>> uint160_t;

	using std::string;



// ============================ secp256k1 signatures and recovery ===================================


	using Signature = Brick<65>;
	using h256		= Brick<32>;
	using Secret	= Brick<32>;
	using Public 	= Brick<64>;

	struct SignatureStruct
	{
		SignatureStruct() = default;

		//SignatureStruct(Signature const& _s) 	{ *((Signature*)this) = _s; }
		//operator Signature() const 			{ return *(Signature const*)this; }


		SignatureStruct(Signature const& _s) {
			auto [tr, ts, tv] = Take<Brick<32>, Brick<32>, Number<uint8_t>>(_s);
			r = tr; s = ts; v = tv;
		}
		operator Signature() const {
			auto [sig] = Take<Brick<65>>(Tie(r, s, Number<uint8_t>(v)));
			return sig;
		}

		/// @returns true if r,s,v values are valid, otherwise false
		bool isValid() const;

		h256 r;
		h256 s;
		byte v = 0;
	};

	bool SignatureStruct::isValid() const
	{
	    static const uint256_t s_max{"0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"};
	    static const uint256_t s_zero;

	    auto tr = r.num<uint256_t>();
	    auto ts = s.num<uint256_t>();

	    return (v <= 1 && tr > s_zero && ts > s_zero && tr < s_max && ts < s_max);
	}

	inline h256 h256_(const uint256_t& x)
	{
		auto t = Number<uint256_t>(x);
		Brick<32> r(t);
		return r;
	}


	secp256k1_context const* getCtx()
	{
		static std::unique_ptr<secp256k1_context, decltype(&secp256k1_context_destroy)> s_ctx{
			secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY),
			&secp256k1_context_destroy
		};
		return s_ctx.get();
	}

	static const uint256_t c_secp256k1n("115792089237316195423570985008687907852837564279074904382605163141518161494337");

	SignatureStruct sign(Secret const& _k, h256 const& _hash)
	{
		auto* ctx = getCtx();
		secp256k1_ecdsa_recoverable_signature rawSig;
		if (!bool(secp256k1_ecdsa_sign_recoverable(ctx, &rawSig, _hash.data(), _k.data(), nullptr, nullptr)))
			return Signature();

		Signature s;
		int v = 0;
		secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, s.data(), &v, &rawSig);


		//SignatureStruct& ss = *reinterpret_cast<SignatureStruct*>(&s);
		SignatureStruct ss(s);
		ss.v = static_cast<byte>(v);
		if (ss.s.num<uint256_t>() > c_secp256k1n / 2)
		{
			ss.v = static_cast<byte>(ss.v ^ 1);
			ss.s = h256_(c_secp256k1n - ss.s.num<uint256_t>());
		}
		assert(ss.s.num<uint256_t>() <= c_secp256k1n / 2);
		assert(ss.isValid());
		return ss;
	}


	Public recover(Signature const& _sig, h256 const& _message)
	{
	    int v = _sig.data()[64];
	    if (v > 3)
	        return {};

	    auto* ctx = getCtx();
	    secp256k1_ecdsa_recoverable_signature rawSig;
	    if (!bool(secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, &rawSig, _sig.data(), v)))
	        return {};

	    secp256k1_pubkey rawPubkey;
	    if (!bool(secp256k1_ecdsa_recover(ctx, &rawPubkey, &rawSig, _message.data())))
	        return {};

	    std::array<byte, 65> serializedPubkey;
	    size_t serializedPubkeySize = serializedPubkey.size();
	    secp256k1_ec_pubkey_serialize(
	            ctx, serializedPubkey.data(), &serializedPubkeySize,
	            &rawPubkey, SECP256K1_EC_UNCOMPRESSED
	    );
	    assert(serializedPubkeySize == serializedPubkey.size());
	    // Expect single byte header of value 0x04 -- uncompressed public key.
	    assert(serializedPubkey[0] == 0x04);
	    // Create the Public skipping the header.
	    return Public{&serializedPubkey[1], 64};
	}


	Address toAddress(Public const& pub)
	{
	    auto h = Hash(pub);
		auto [unused, addr] = Take<Brick<12>, Brick<20>>(Tie(h));
	    Address x(addr.num<uint160_t>());
	    return x;
	}


	void test_SignAndRecover()
	{
	    // This basic test that compares **fixed** results. Useful to test new
	    // implementations or changes to implementations.
	    auto sec = Secret{Hash("sec")};
	    auto msg = Hash("msg");
	    Signature sig = sign(sec, msg);
	    auto expectedSig = "0xb826808a8c41e00b7c5d71f211f005a84a7b97949d5e765831e1da4e34c9b8295d2a622eee50f25af78241c1cb7cfff11bcf2a13fe65dee1e3b86fd79a4e3ed000";
	    std::cout << " sig  : " << sig.hex()  << std::endl;
	    std::cout << " esig : " << expectedSig << std::endl;
	    assert(sig.hex() == ( expectedSig));

	    auto pub = recover(sig, msg);
	    auto expectedPub = "0xe40930c838d6cca526795596e368d16083f0672f4ab61788277abfa23c3740e1cc84453b0b24f49086feba0bd978bb4446bae8dff1e79fcc1e9cf482ec2d07c3";
	    std::cout << " pub  : " << pub.hex()  << std::endl;
	    std::cout << " epub : " << expectedPub << std::endl;
	    assert(pub.hex() == ( expectedPub));
	}




// ============================ ===================================


    void test()
    {
        //return Wait([&]() -> task<int> { co_await Schedule(); Endpoint endpoint({"http", "localhost", "8545", "/"}); /* code here */ }() );
    }

    inline task<string> deploy(Endpoint& endpoint, const string& address, const string& bin)
    {
        printf("[%d] deploy [%i] \n", __LINE__, int(bin.size()) );
   		assert(bin.size() > 2);
        auto trans_hash = co_await endpoint("eth_sendTransaction", {Multi{{"from",uint256_t(address)},{"data",bin}, {"gas","4712388"}, {"gasPrice","100000000000"}}} );
        // todo: this currently works on EthereumJS TestRPC v6.0.3, but on a live network you'd need to wait for the transaction to be mined
   		auto result     = co_await endpoint("eth_getTransactionReceipt", {trans_hash.asString()} );
   		string contractAddress = result["contractAddress"].asString();
        co_return contractAddress;
    }

    task<int> test_lottery()
    {
    	test_SignAndRecover();

        Endpoint endpoint(GetLocal(), {"http", "localhost", "8545", "/"});

        co_await endpoint("web3_clientVersion", {});


	    // this assumes testrpc started as:
	    // testrpc -d --network-id 10
	    // to get deterministic test accounts (`testAcc` is the first account)
	    // --network-id 10 is needed to workaround
	    // https://github.com/ethereum/web3.js/issues/932 (wtf)

        printf("[%d] Example start\n", __LINE__);


   		auto is_syncing = co_await endpoint("eth_syncing", {});
   		std::cout << "result: \n" << is_syncing << std::endl;
   		if (is_syncing != false) {
   			std::cout << "Host unavailable/not working" << std::endl;
   			co_return 3;
   		}





        // this is the account which sets up the token contracts
        // taken from testrpc
        const string token_address = "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1";
        const string token_privkey = "4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d";

        const string server_address  = "0xffcf8fdee72ac11b5c542428b35eef5769c409f0";
        const string server_address_ = "000000000000000000000000ffcf8fdee72ac11b5c542428b35eef5769c409f0";
        const string server_privkey  = "6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1";

   		const string client_address = "0x22d491bde2303f2f43325b2108d26f1eaba1e32b";
   		const string client_privkey = "6370fd033278c143179d81c5526140625662b8daa446c22ee2d73db3707e620c";

   		const string test_privkey = "9c7a42cd9603bd9b7baee8b37281b2f483de254ccca34b9d764e72e89addfb64";



   		printf("[%d] Deploying some contracts! \n", __LINE__ );

   		auto block(co_await endpoint.Latest());
   		Json::Value result;

   		string test_contract_bin  	= "6060604052341561000c57fe5b5b6101598061001c6000396000f30060606040526000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063cfae32171461003b575bfe5b341561004357fe5b61004b6100d4565b604051808060200182810382528381815181526020019150805190602001908083836000831461009a575b80518252602083111561009a57602082019150602081019050602083039250610076565b505050905090810190601f1680156100c65780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b6100dc610119565b604060405190810160405280600381526020017f486921000000000000000000000000000000000000000000000000000000000081525090505b90565b6020604051908101604052806000815250905600a165627a7a72305820ed71008611bb64338581c5758f96e31ac3b0c57e1d8de028b72f0b8173ff93a10029";
   		string test_contract_addr 	= co_await deploy(endpoint, token_address, "0x" + test_contract_bin);
        string ERC20_addr 			= co_await deploy(endpoint, token_address, load_solcbin_as_string("tok-ethereum/build/ERC20.bin"));
        string OrchidToken_addr 	= co_await deploy(endpoint, token_address, load_solcbin_as_string("tok-ethereum/build/OrchidToken.bin"));

		printf("[%d] OrchidToken_addr(%s,%s) \n", __LINE__, OrchidToken_addr.c_str(), OrchidToken_addr.c_str());


        string lottery_addr		 	= co_await deploy(endpoint, token_address, load_solcbin_as_string("lot-ethereum/build/TestOrchidLottery.bin"));
   		printf("[%d] lottery_addr(%s,%s) \n", __LINE__, lottery_addr.c_str(), lottery_addr.c_str());


   		block = co_await endpoint.Latest();

        // test ecrecover
   		{
   		    auto sec  = Secret{Hash("sec")};
   		    auto msg  = Hash("msg");
   		    auto sig  = sign(sec, msg);
   		    auto pub  = recover(sig, msg);
   		    auto addr = toAddress(pub);

   		    static Selector<uint256_t, Bytes32, uint8_t, Bytes32, Bytes32, Address> test_ecrecover("test_ecrecover");
   		    // sig.v + 27 is necessary, doesn't make any sense
   		    // https://github.com/ethereum/wiki/wiki/JavaScript-API#web3ethsign
			auto raddr	= co_await test_ecrecover.Call(endpoint, block, Address(lottery_addr), msg, sig.v + 27, sig.r, sig.s, addr);

			std::cout << " sig(" << uint(sig.v) << ", " << sig.r << ", " << sig.s << std::endl;
			std::cout << std::hex << " raddr: " << raddr << " " << addr << std::endl;
   		}



        //set the token address (todo: figure out contract constructor args)
   		static Selector<uint256_t, Address> set_token("set_token");
   		co_await set_token.Send(endpoint, Address(token_address), Address(lottery_addr), Address(OrchidToken_addr) );



   		static Selector<Address,uint256_t> get_address("get_address");
   		auto lottery_addr_ = co_await get_address.Call(endpoint, block, Address(lottery_addr), uint256_t("3")  );

   		static Selector<Address,uint256_t> get_token("get_token");
   		auto lottery_token = co_await get_token.Call(endpoint, block, Address(lottery_addr), uint256_t("4") );
		printf("[%d] lottery_token: ", __LINE__); std::cout << std::hex << lottery_token << std::endl;



	    //const source_OCT = await c.ledger.methods.balanceOf(source.address).call();
	    Selector<uint256_t,Address> balanceOf("balanceOf");
   		auto origin_balance = co_await balanceOf.Call(endpoint, block, Address(OrchidToken_addr), Address(token_address) );
		printf("[%d] origin_balance: ", __LINE__); std::cout << std::dec << origin_balance << std::endl;


	    uint64_t one_eth = 1000000000000000000;
   		// send some tokens to the client
   		static Selector<uint256_t, Address, uint256_t> transfer("transfer");
   		co_await transfer.Send(endpoint, Address(token_address), Address(OrchidToken_addr), Address(client_address), uint256_t(10*one_eth) );


   		block = co_await endpoint.Latest();
   		auto client_balance = co_await balanceOf.Call(endpoint, block, Address(OrchidToken_addr), Address(client_address) );
		printf("[%d] client_balance: ", __LINE__); std::cout << std::dec << client_balance << std::endl;


   		static Selector<uint256_t, Address, uint256_t> approve("approve");
   		co_await approve.Send(endpoint, Address(client_address), Address(OrchidToken_addr), Address(lottery_addr), uint256_t(10*one_eth) );


   		// approve and fund the client account
        //const allow_val = await c.ledger.methods.allowance(source.address, lotteryAddr).call();
   		block = co_await endpoint.Latest();
   		static Selector<uint256_t, Address, Address> allowance_f("allowance");
   		auto allowance 				= co_await allowance_f.Call(endpoint, block, Address(OrchidToken_addr), Address(client_address), Address(lottery_addr) );
		printf("[%d] allowance: ", __LINE__); std::cout << std::dec << allowance << std::endl;


   		static Selector<uint256_t, Address,uint64_t,uint64_t> fund_f("fund");
   		co_await fund_f.Send(endpoint, Address(client_address), Address(lottery_addr), Address(client_address), uint64_t(1*one_eth), uint64_t(2*one_eth) );
        //result					= co_await endpoint("eth_sendTransaction", {Multi{{"to", uint256_t(lottery_addr)},    {"from",uint256_t(client_address)},{"data", Tie(Selector("fund(address,uint64,uint64)"),Number<uint256_t>(client_address),Number<uint256_t>(1*one_eth),Number<uint256_t>(2*one_eth)) }, {"gas","100000"}, {"gasPrice","100000000000"}}} );


   		static Selector<uint256_t, Address> get_amount("get_amount");
   		static Selector<uint256_t, Address> get_escrow("get_escrow");
   		static Selector<uint256_t, Address> get_unlock("get_unlock");

   		block = co_await endpoint.Latest();
   		auto amount	= co_await get_amount.Call(endpoint, block, Address(lottery_addr), Address(client_address));
   		auto escrow	= co_await get_escrow.Call(endpoint, block, Address(lottery_addr), Address(client_address));
   		auto unlock	= co_await get_unlock.Call(endpoint, block, Address(lottery_addr), Address(client_address));

		printf("[%d] amount: ", __LINE__); std::cout << std::dec << amount << std::endl;
		printf("[%d] escrow: ", __LINE__); std::cout << std::dec << escrow << std::endl;
		printf("[%d] unlock: ", __LINE__); std::cout << std::dec << unlock << std::endl;

	    // simple hash consistency check
   		{
			Brick<32> hash		 	= Hash(Tie(Number<uint160_t>(server_address)));
	   		static Selector<uint256_t, Address> hash_test_("hash_test_");
	   		auto hash2				= co_await hash_test_.Call(endpoint, block, Address(lottery_addr), Address(server_address));

			printf("[%d] hash: ", __LINE__);  std::cout << std::hex << hash << "  " << hash2 << std::endl;
			assert( hash.num<uint256_t>() == uint256_t(hash2) );
   		}



   		uint256_t secret		= 1;
   		Brick<32> secret_hash 	= Hash(Tie(Number<uint256_t>(secret)));
	    uint64_t faceValue 		= one_eth / 10;
	    uint256_t until			= std::time(nullptr) + 1000000;
	    uint256_t winProb     	= uint256_t("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
	    uint256_t nonce       	= uint256_t("0x24a025cfe44e8cca34ee5028817704a213dedf2108cdb1c1717270646c8f26b1");


	    Brick<32> hash		 	= Hash(Tie(secret_hash, Number<uint160_t>(server_address), Number<uint256_t>(nonce), Number<uint256_t>(until), Number<uint256_t>(winProb), Number<uint64_t>(faceValue)));

	    // test signatures
    	auto csig 		= sign(h256_(uint256_t("0x" + client_privkey)), hash);
	    {

	    	auto rpubkey 	= recover(csig, hash);
	    	auto raddress   = toAddress(rpubkey);
	   		std::cout << "sign(" << std::hex << client_privkey << ", " << hash << ") = " << csig << std::endl;
	   		std::cout << " rpubkey: "  << rpubkey  << std::endl;
	   		std::cout << " raddress: " << raddress << std::endl;
	   		//assert(raddress == Address(client_address) );
	   		assert(uint256_t(raddress) == uint256_t(Address(client_address)));
	    }



	    // full hash consistency check
	    {
	   		static Selector<uint256_t, Bytes32, Address, uint256_t, uint256_t, uint256_t, uint64_t> hash_test("hash_test");
	   		auto hash2				= co_await hash_test.Call(endpoint, block, Address(lottery_addr), secret_hash, Address(server_address), uint256_t(nonce), uint256_t(until), uint256_t(winProb), uint64_t(faceValue) );


			printf("[%d] hash: ", __LINE__);  std::cout << std::hex << hash << "  " << hash2 << std::endl;
			assert( hash.num<uint256_t>() == uint256_t(hash2) );
	    }



   		static Selector<uint256_t, uint256_t, Bytes32, Address, uint256_t, uint256_t, uint256_t, uint64_t, uint8_t, Bytes32, Bytes32, Address, Bytes32> grab2("grab2");
   	    //function grab2(uint256 secret, bytes32 hash, address payable target, uint256 nonce, uint256 until, uint256 ratio, uint64 amount, uint8 v, bytes32 r, bytes32 s) public
   		co_await grab2.Send(endpoint, Address(server_address), Address(lottery_addr), secret, secret_hash, Address(server_address), uint256_t(nonce), uint256_t(until), uint256_t(winProb), uint64_t(faceValue), csig.v + 27, csig.r, csig.s, Address(client_address), hash);


   		std::cout << "Done." << std::endl;
   		co_return 0;
    }


    int test_lot()
    {
        std::cout << "test_lot()" << std::endl;
        auto t = test_lottery();
        sync_wait(t);        
        std::cout << "test_lot(): done" << std::endl;
        return 0;
    }

}

