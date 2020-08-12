import os
import sys

#export WEB3_INFURA_PROJECT_ID=aca6dac91cf34aadb23005b60d38b603
os.environ['WEB3_INFURA_PROJECT_ID'] = 'aca6dac91cf34aadb23005b60d38b603'
from web3.auto.infura import w3

import web3.exceptions
import time
import datetime
import requests
import math
import argparse


GasPrice = '60'


token_abi = [{"inputs": [], "payable": False, "stateMutability": "nonpayable", "type": "constructor"}, {"anonymous": False, "inputs": [{"indexed": True, "internalType": "address", "name": "owner", "type": "address"}, {"indexed": True, "internalType": "address", "name": "spender", "type": "address"}, {"indexed": False, "internalType": "uint256", "name": "value", "type": "uint256"} ], "name": "Approval", "type": "event"}, {"anonymous": False, "inputs": [{"indexed": True, "internalType": "address", "name": "from", "type": "address"}, {"indexed": True, "internalType": "address", "name": "to", "type": "address"}, {"indexed": False, "internalType": "uint256", "name": "value", "type": "uint256"} ], "name": "Transfer", "type": "event"}, {"constant": True, "inputs": [{"internalType": "address", "name": "owner", "type": "address"}, {"internalType": "address", "name": "spender", "type": "address"} ], "name": "allowance", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": False, "inputs": [{"internalType": "address", "name": "spender", "type": "address"}, {"internalType": "uint256", "name": "amount", "type": "uint256"} ], "name": "approve", "outputs": [{"internalType": "bool", "name": "", "type": "bool"} ], "payable": False, "stateMutability": "nonpayable", "type": "function"}, {"constant": True, "inputs": [{"internalType": "address", "name": "account", "type": "address"} ], "name": "balanceOf", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": True, "inputs": [], "name": "decimals", "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": False, "inputs": [{"internalType": "address", "name": "spender", "type": "address"}, {"internalType": "uint256", "name": "subtractedValue", "type": "uint256"} ], "name": "decreaseAllowance", "outputs": [{"internalType": "bool", "name": "", "type": "bool"} ], "payable": False, "stateMutability": "nonpayable", "type": "function"}, {"constant": False, "inputs": [{"internalType": "address", "name": "spender", "type": "address"}, {"internalType": "uint256", "name": "addedValue", "type": "uint256"} ], "name": "increaseAllowance", "outputs": [{"internalType": "bool", "name": "", "type": "bool"} ], "payable": False, "stateMutability": "nonpayable", "type": "function"}, {"constant": True, "inputs": [], "name": "name", "outputs": [{"internalType": "string", "name": "", "type": "string"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": True, "inputs": [], "name": "symbol", "outputs": [{"internalType": "string", "name": "", "type": "string"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": True, "inputs": [], "name": "totalSupply", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"} ], "payable": False, "stateMutability": "view", "type": "function"}, {"constant": False, "inputs": [{"internalType": "address", "name": "recipient", "type": "address"}, {"internalType": "uint256", "name": "amount", "type": "uint256"} ], "name": "transfer", "outputs": [{"internalType": "bool", "name": "", "type": "bool"} ], "payable": False, "stateMutability": "nonpayable", "type": "function"}, {"constant": False, "inputs": [{"internalType": "address", "name": "sender", "type": "address"}, {"internalType": "address", "name": "recipient", "type": "address"}, {"internalType": "uint256", "name": "amount", "type": "uint256"} ], "name": "transferFrom", "outputs": [{"internalType": "bool", "name": "", "type": "bool"} ], "payable": False, "stateMutability": "nonpayable", "type": "function"} ];

#distributor_abi = [{"inputs":[{"internalType":"contract IERC20","name":"token","type":"address"}],"payable":False,"stateMutability":"nonpayable","type":"constructor"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"calculate","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"compute_owed","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"compute_owed_","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[],"name":"distribute_all","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":False,"inputs":[{"internalType":"uint256","name":"N","type":"uint256"}],"name":"distribute_partial","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"num_limits","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"rec","type":"address"},{"internalType":"uint256","name":"idx","type":"uint256"},{"internalType":"uint128","name":"beg","type":"uint128"},{"internalType":"uint128","name":"end","type":"uint128"},{"internalType":"uint128","name":"amt","type":"uint128"},{"internalType":"uint128","name":"sent","type":"uint128"}],"name":"update","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"what","outputs":[{"internalType":"contract IERC20","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"}];
#distributor_abi = [{"inputs":[{"internalType":"contract IERC20","name":"token","type":"address"}],"payable":False,"stateMutability":"nonpayable","type":"constructor"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"calculate","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"calculate_at","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"compute_owed","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"compute_owed_","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[],"name":"distribute_all","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":False,"inputs":[{"internalType":"uint256","name":"N","type":"uint256"}],"name":"distribute_partial","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_amt","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_beg","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_end","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"num_limits","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"rec","type":"address"},{"internalType":"uint256","name":"idx","type":"uint256"},{"internalType":"uint128","name":"beg","type":"uint128"},{"internalType":"uint128","name":"end","type":"uint128"},{"internalType":"uint128","name":"amt","type":"uint128"},{"internalType":"uint128","name":"sent","type":"uint128"}],"name":"update","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"what","outputs":[{"internalType":"contract IERC20","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"}]

distributor_abi = [{"inputs":[{"internalType":"contract IERC20","name":"token","type":"address"}],"payable":False,"stateMutability":"nonpayable","type":"constructor"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"calculate","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"calculate_at","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"compute_owed","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"t","type":"uint256"}],"name":"compute_owed_","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[],"name":"distribute_all","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":False,"inputs":[{"internalType":"uint256","name":"N","type":"uint256"}],"name":"distribute_partial","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_amt","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_beg","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"},{"internalType":"uint256","name":"i","type":"uint256"}],"name":"get_end","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"a","type":"address"}],"name":"num_limits","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"rec","type":"address"},{"internalType":"uint256","name":"idx","type":"uint256"},{"internalType":"uint128","name":"beg","type":"uint128"},{"internalType":"uint128","name":"end","type":"uint128"},{"internalType":"uint128","name":"amt","type":"uint128"},{"internalType":"uint128","name":"sent","type":"uint128"}],"name":"update","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"what","outputs":[{"internalType":"contract IERC20","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"}]

test_account = w3.eth.account.create('test')
#print(f"test_account.address: {test_account.address} ");
#print(f"test_account.privateKey: {test_account.privateKey.hex()} ");


print("Creating Token contract object from abi.");
Token = w3.eth.contract(abi=token_abi)

print("Creating Distributor contract object from abi.");
Distributor = w3.eth.contract(abi=distributor_abi)

distributor_main = Distributor(address = '0xB22613B150e6267dE62460804E119007E0aD4117')

def update(rec, idx, beg, end, amt, amt_sent, funder_pubkey, funder_privkey, nonce):

	#time = (beg << 32) | end;
	#print(f"time:{time} beg:{beg} end:{end}");
    #function update(address rec, uint idx, uint beg, uint end, uint128 amt) public {

	txn = distributor_main.functions.update(rec, idx, beg, end, w3.toWei(amt, 'ether'), w3.toWei(amt_sent, 'ether')
		).buildTransaction({'chainId': 1, 'from': funder_pubkey, 'gas': 250000, 'gasPrice': w3.toWei(GasPrice, 'gwei'), 'nonce':nonce, }
	)

	print("Funder signed transaction:");
	txn_signed = w3.eth.account.sign_transaction(txn, private_key=funder_privkey)
	print(txn_signed);

	print("Submitting transaction:");
	txn_hash = w3.eth.sendRawTransaction(txn_signed.rawTransaction);
	print(f"Submitted transaction with hash: {txn_hash.hex()}");


def distribute_partial(N, funder_pubkey, funder_privkey, nonce):

	print(f"distribute_partial({N},{funder_pubkey},{funder_privkey},{nonce})");

	gas = 32000 + 40000*N;
	txn = distributor_main.functions.distribute_partial(N
		).buildTransaction({'chainId': 1, 'from': funder_pubkey, 'gas': gas, 'gasPrice': w3.toWei(GasPrice, 'gwei'), 'nonce':nonce, }
	)

	print("Funder signed transaction:");
	txn_signed = w3.eth.account.sign_transaction(txn, private_key=funder_privkey)
	print(txn_signed);

	print("Submitting transaction:");
	txn_hash = w3.eth.sendRawTransaction(txn_signed.rawTransaction);
	print(f"Submitted transaction with hash: {txn_hash.hex()}");
	nonce += 1

	return nonce


def date(m,d,y):
	unixtime = int(time.mktime(datetime.date(y,m,d).timetuple()));
	return unixtime;

"""
def add_employee(k0,k1,addr, M,D,Y, amt_owed, amt_sent, n):
	update(addr, 0, date( M,D,Y+1),  date( M, D,Y+1),  amt_owed, amt_sent, k0,k1,n+0); # cliff 1 year from start date
	update(addr, 1, date( M,D,Y+0),  date( M, D,Y+4),  amt_owed, amt_sent, k0,k1,n+1); # 4 year vest
	update(addr, 2, date(12,31,2019),date(12, 5,2020), amt_owed, amt_sent, k0,k1,n+2); # 1 year trade lockup
"""

def add_employee(a,n):
	M = a.M
	D = a.D
	Y = a.Y
	k0 = a.FUNDER_PUBKEY
	k1 = a.FUNDER_PRIVKEY
	update(a.addr, 0, date( M,D,Y+1),  date(M,D,Y+1),  a.amt_owed, a.amt_sent, k0,k1,n+0); # cliff 1 year from start date
	update(a.addr, 1, date( M,D,Y+0),  date(M,D,Y+4),  a.amt_owed, a.amt_sent, k0,k1,n+1); # 4 year vest
	update(a.addr, 2, date(12,31,2019),date(12, 5,2020), a.amt_owed, a.amt_sent, k0,k1,n+2); # 1 year trade lockup


def update_send_list(k0,k1,n):

	print("Updating distribution list.");

	add_employee(k0,k1,'0x7361c5B033dc7209a81e8e60BF5e19DD66270672', 7,11,2018, 1000000, 270000, n); n+=3; # cliff 1 year from start date

	return n;


def debug_send(a,n):
	rec = a.addr
	k0 = a.FUNDER_PUBKEY
	k1 = a.FUNDER_PRIVKEY

	#badrec = '0x4a31c1B033dc7209a82e8e60BF5e19DD662705e8';
	#owed_wei = distributor_main.functions.calculate(badrec, date(3,5,2020) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	#print(f"total to {badrec} at 3/5/2020 : {owed}");


	#rec = '0x7361c5B033dc7209a81e8e60BF5e19DD66270672';

	num_funcs = distributor_main.functions.num_limits(rec).call();
	print(f"{rec} has {num_funcs} funcs");

	if (num_funcs > 0):
		temp = distributor_main.functions.get_beg(rec,0).call();
		#print(f"get_beg({rec},0): {temp} ");
		temp = distributor_main.functions.get_end(rec,0).call();
		#print(f"get_end({rec},0): {temp} ");
		temp = distributor_main.functions.get_amt(rec,0).call();
		#print(f"get_amt({rec},0): {temp} ");


		temp = distributor_main.functions.get_beg(rec,1).call();
		#print(f"get_beg({rec},1): {temp} ");
		temp = distributor_main.functions.get_end(rec,1).call();
		#print(f"get_end({rec},1): {temp} ");
		temp = distributor_main.functions.get_amt(rec,1).call();
		#print(f"get_amt({rec},1): {temp} ");


		owed_wei = distributor_main.functions.calculate_at(rec, date(3,5,2020), 0).call(); owed = w3.fromWei(owed_wei, 'ether');
		print(f"calculate_at( {rec}, 3/5/2020, 0) : {owed}");ValueError: {'code': -32000, 'message': 'transaction underpriced'}
		owed_wei = distributor_main.functions.calculate_at(rec, date(3,5,2020), 1).call(); owed = w3.fromWei(owed_wei, 'ether');
		print(f"calculate_at( {rec}, 3/5/2020, 1) : {owed}");
		owed_wei = distributor_main.functions.calculate_at(rec, date(3,5,2020), 2).call(); owed = w3.fromWei(owed_wei, 'ether');
		print(f"calculate_at( {rec}, 3/5/2020, 2) : {owed}");


	owed_wei = distributor_main.functions.calculate(rec, date(3,5,2020) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"total to {rec} at 3/5/2020 : {owed}");


	owed_wei = distributor_main.functions.compute_owed_(rec, date(3,5,2020) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"owed to {rec} at 3/5/2020 : {owed}");

	owed_wei = distributor_main.functions.compute_owed_(rec, date(4,5,2020) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"owed to {rec} at 4/5/2020 : {owed}");

	owed_wei = distributor_main.functions.compute_owed_(rec, date(10,5,2020) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"owed to {rec} at 10/5/2020 : {owed}");

	owed_wei = distributor_main.functions.compute_owed_(rec, date(1,5,2021) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"owed to {rec} at 1/5/2021 : {owed}");

	owed_wei = distributor_main.functions.compute_owed_(rec, date(1,5,2023) ).call(); owed = w3.fromWei(owed_wei, 'ether');
	print(f"owed to {rec} at 1/5/2023 : {owed}");

	unixtime = date(3,27,2020)
	print(f"3/27/2020: {unixtime}");

	return n;


def send(funder_pubkey, funder_privkey, N):

	print("Distributor functions:");
	print( Distributor.all_functions() )

	nonce = w3.eth.getTransactionCount(funder_pubkey);
	print(f"Funder nonce: {nonce}");

	k0 = funder_pubkey;
	k1 = funder_privkey;
	n  = nonce;

	#n = update_send_list(k0,k1,n);
	n = debug_send(k0,k1,n);

	print(f"Sending {N}: ");
	for i in range(int(math.ceil(N/8.0))):
		print(".");
		n = distribute_partial(8,k0,k1,n);


def main():
	print(".")
	parser = argparse.ArgumentParser(description='Distribute some OXT.')
	parser.add_argument('FUNDER_PUBKEY',  help='funder publickey')
	parser.add_argument('FUNDER_PRIVKEY', help='funder privkey')


	subparsers = parser.add_subparsers(help='sub-command help')

	#def add_employee(k0,k1,addr, M,D,Y, amt_owed, amt_sent, n):
	parser_add_employee = subparsers.add_parser('add_employee', help='add employee')
	parser_add_employee.add_argument('addr', 	help='address')
	parser_add_employee.add_argument('M', 	type=int, help='month')
	parser_add_employee.add_argument('D', 	type=int, help='day')
	parser_add_employee.add_argument('Y', 	type=int, help='year')
	parser_add_employee.add_argument('amt_owed', help='amt_owed')
	parser_add_employee.add_argument('amt_sent', help='amt_sent')
	parser_add_employee.set_defaults(func=add_employee)

	distribute 			= subparsers.add_parser('distribute', help='distribute')

	parser_debug_send = subparsers.add_parser('debug_send', help='debug_send')
	parser_debug_send.add_argument('addr', 	help='address')
	parser_debug_send.set_defaults(func=debug_send)

	#parser.add_argument('COMMAND',  	  nargs=1,help='command to run')
	args = parser.parse_args()

	funder_pubkey = args.FUNDER_PUBKEY;
	funder_pubkey2 = '0x25A20D9bd3e69a4c20E636F2679F2a19f595dA25';
	print(f"pubkey: {funder_pubkey}  {funder_pubkey2}")
	nonce = w3.eth.getTransactionCount(funder_pubkey);

	args.func(args, nonce)
	#sys.exit(args.func(args) or 0)

    #sys.exit(args.func(args))

"""

def main():

	if len(sys.argv) > 2 :
		#signer = sys.argv[1];
		N = 8;
		if len(sys.argv) > 3:
			N = sys.argv[3];
		send(sys.argv[1], sys.argv[2], int(N))
	else :
		print("usage: distribute.py FUNDER_PUBKEY FUNDER_PRIVKEY N");

"""

if __name__ == "__main__":
    main()
