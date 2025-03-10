# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"

include Axentro::Core
include Units::Utils
include Axentro::Core::Controllers
include Axentro::Core::Keys

private def asset_blockchain(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

private def asset_blockchain_header(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain_header(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

describe RESTController do
  describe "__v1_blockchain" do
    it "should return the full blockchain with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain("/api/v1/blockchain") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(100)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain("/api/v1/blockchain?direction=up") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(0)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain("/api/v1/blockchain?page=2&per_page=1&direction=down") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(1)
        blocks.first.index.should eq(98)
      end
    end
  end

  describe "__v1_blockchain_header" do
    it "should return the blockchain headers with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(100)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain_header("/api/v1/blockchain/header/?direction=up") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(0)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header?page=2&per_page=1&direction=down") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(1)
        blocks.first[:index].should eq(98)
      end
    end
  end

  describe "__v1_blockchain_size" do
    it "should return the full blockchain size when chain fits into memory" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain_size(context("/api/v1/blockchain/size"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["totals"]["total_size"].should eq(3)
          result["result"]["totals"]["total_fast"].should eq(0)
          result["result"]["totals"]["total_slow"].should eq(3)
          result["result"]["block_height"]["fast"].should eq(0)
          result["result"]["block_height"]["slow"].should eq(4)
        end
      end
    end
  end

  describe "__v1_block_index" do
    it "should return the block for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          Block.from_json(result["result"]["block"].to_json)
        end
      end
    end
    it "should failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block/99"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_header" do
    it "should return the block header for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/0/header"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::Header.from_json(result["result"].to_json)
        end
      end
    end
    it "should return failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/99/header"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_transactions" do
    it "should return the block transactions for the specified index" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/0/header"), {index: 2})) do |result|
          result["status"].to_s.should eq("success")
          Array(Transaction).from_json(result["result"]["transactions"].to_json)
          result["result"]["confirmations"].as_i.should eq(2)
        end
      end
    end
  end

  describe "__v1_transaction_id" do
    it "should return the transaction for the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/#{transaction.id}"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].to_s.should eq("accepted")
          Transaction.from_json(result["result"]["transaction"].to_json)
        end
      end
    end
    it "should return not found when specified transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/non-existing-txn-id"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].should eq("not found")
        end
      end
    end
  end

  describe "__v1_transaction_id_block" do
    it "should return the block containing the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block(context("/api/v1/transaction/#{transaction.id}/block"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          Block.from_json(result["result"]["block"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block(context("/api/v1/transaction/non-existing-txn-id/block"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_id_block_header" do
    it "should return the block header containing the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/#{transaction.id}/block/header"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::Header.from_json(result["result"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/non-existing-txn-id/block/header"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_fees" do
    it "should return the transaction fees" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_fees(context("/api/v1/transaction/fees"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["send"].should eq("0.0001")
          result["result"]["hra_buy"].should eq("0.001")
          result["result"]["hra_sell"].should eq("0.0001")
          result["result"]["hra_cancel"].should eq("0.0001")
          result["result"]["create_token"].should eq("10")
        end
      end
    end
  end

  describe "__v1_address" do
    it "should return the amounts for the specified address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"23.9999812\"}")
        end
      end
    end
    it "should return zero amount when address is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/non-existing-address"), {address: "non-existing-address"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"0\"}")
        end
      end
    end
  end

  describe "__v1_address_token" do
    it "should return the amounts for the specified address and token" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/#{address}/token/AXNT"), {address: address, token: "AXNT"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"23.9999812\"}")
        end
      end
    end
    it "should return no pairs when address and token is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/non-existing-address/token/NONE"), {address: "non-existing-address", token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"].to_s.should eq("[]")
        end
      end
    end
  end

  describe "__v1_address_transactions" do
    it "should return all transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          Array(Transaction).from_json(data)
        end
      end
    end
    it "should return filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=send"), {address: address, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.map(&.action).uniq!.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=unknown"), {address: address, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["transactions"].to_s.should eq("[]")
        end
      end
    end
    it "should return empty result when specified address and filter is not found" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/no-address/transactions?actions=unknown"), {address: "no-address", actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["transactions"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.add_slow_blocks(100)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.add_slow_blocks(200)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?per_page=50&page=2"), {address: address, page_size: 50, page: 2})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(50)
        end
      end
    end
  end

  describe "__v1_domain" do
    it "should return the amounts for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain(context("/api/v1/domain/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"35.99996241\"}")
        end
      end
    end
    it "should return error amount when domain is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain(context("/api/v1/domain/non-existing-domain"), {domain: "non-existing-domain"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("the domain non-existing-domain is not resolved")
        end
      end
    end
  end

  describe "__v1_domain_token" do
    it "should return the amounts for the specified domain and token" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/domain/#{domain}/token/AXNT"), {domain: domain, token: "AXNT"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"35.99996241\"}")
        end
      end
    end
    it "should return no pairs when token is not found" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/address/#{domain}/token/NONE"), {domain: domain, token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"].to_s.should eq("[]")
        end
      end
    end
  end

  describe "__v1_domain_transactions" do
    it "should return all transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          Array(Transaction).from_json(data)
        end
      end
    end
    it "should return filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=send"), {domain: domain, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.map(&.action).uniq!.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=unknown"), {domain: domain, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["transactions"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(100)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(200)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?per_page=50&page=2"), {domain: domain, page_size: 50, page: 1})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["transactions"].as_a.map(&.["transaction"]).to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(50)
        end
      end
    end
  end

  describe "__v1_hra_sales" do
    it "should return the domains for sale" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2).add_slow_block([transaction_factory.make_sell_domain(domain, 1_i64)]).add_slow_blocks(3)

        exec_rest_api(block_factory.rest.__v1_hra_sales(context("/api/v1/hra/sales"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result = Array(DomainResult).from_json(result["result"].to_json).first
          result.domain_name.should eq(domain)
          result.status.should eq(1_i64)
          result.price.should eq("0.00000001")
        end
      end
    end
  end

  describe "__v1_hra" do
    it "should return true when domain is resolved" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_hra(context("/api/v1/hra/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["resolved"].to_s.should eq("true")
        end
      end
    end
    it "should return false when domain is not resolved" do
      with_factory do |block_factory, _|
        domain = "axentro.ax"
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_hra(context("/api/v1/hra/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["resolved"].to_s.should eq("false")
        end
      end
    end
    it "should return a list of domains" do
      with_factory do |block_factory, transaction_factory|
        domains = ["domain1.ax", "domain2.ax"]
        block_factory.add_slow_blocks(2).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domains[0], 0_i64)]).add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_hra_lookup(context("/api/v1/hra/lookup/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result_domains = Array(DomainResult).from_json(result["result"]["domains"].to_json)
          result_domains.first.domain_name.should eq(domains[0])
        end
      end
    end
    it "should return the correct list of domains after a domain has been sold" do
      with_factory do |block_factory, transaction_factory|
        domain_name = "domain1.ax"
        domain_name2 = "domain2.ax"
        block_factory.add_slow_blocks(2).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domain_name, 0_i64),
           transaction_factory.make_buy_domain_from_platform(domain_name2, 0_i64),
          ])
          .add_slow_blocks(2)
          .add_slow_block([transaction_factory.make_sell_domain(domain_name, 100_i64)])
          .add_slow_block([transaction_factory.make_send(2000000000)])
          .add_slow_block([transaction_factory.make_buy_domain_from_seller(domain_name, 100_i64)])
          .add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_hra_lookup(context("/api/v1/hra/lookup/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result_domains = Array(DomainResult).from_json(result["result"]["domains"].to_json)
          result_domains.size.should eq(1)
          result_domains.first.domain_name.should eq(domain_name2)
        end
      end
    end
  end

  describe "__v1_tokens" do
    it "should return a list of existing tokens" do
      with_factory do |block_factory, transaction_factory|
        token = "KINGS"
        block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_create_token(token, 10000_i64)]).add_slow_blocks(3)
        exec_rest_api(block_factory.rest.__v1_tokens(context("/api/v1/tokens"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[\"AXNT\", \"KINGS\"]")
        end
      end
    end
  end

  describe "__v1_wallet" do
    it "should return wallet info for the supplied address or domain" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_wallet(context("/api/v1/wallet/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["address"].to_s.should eq(address)
        end
      end
    end
  end

  describe "__v1_search" do
    it "should search for the supplied address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_search(context("/api/v1/search/#{address}"), {term: address})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["category"].to_s.should eq("address")
        end
      end
    end

    it "should search for the supplied domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_search(context("/api/v1/search/#{domain}"), {term: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["category"].to_s.should eq("domain")
        end
      end
    end

    it "should search for the supplied transaction id" do
      with_factory do |block_factory, _|
        transaction_id = block_factory.chain.last.transactions.last.id
        exec_rest_api(block_factory.rest.__v1_search(context("/api/v1/search/#{transaction_id}"), {term: transaction_id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["category"].to_s.should eq("transaction")
        end
      end
    end

    it "should search for the supplied block id" do
      with_factory do |block_factory, _|
        block_id = block_factory.chain.last.index
        exec_rest_api(block_factory.rest.__v1_search(context("/api/v1/search/#{block_id}"), {term: block_id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["category"].to_s.should eq("block")
        end
      end
    end
  end

  describe "__v1_node" do
    it "should return info about the connecting node" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_node(context("/api/v1/node"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          NodeResult.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_nodes" do
    it "should return info about the connecting node" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_nodes(context("/api/v1/nodes"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          NodesResult.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_node_id" do
    it "should return a message when node is not connected to any other nodes" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_node_id(context("/api/v1/node/node_id"), {id: "node_id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].to_s.should eq("the node node_id not found. (only searching nodes which are currently connected.)")
        end
      end
    end
  end

  describe "__v1_nonces" do
    it "should return nonces for an address" do
      with_factory do |block_factory, _|
        address = block_factory.node_wallet.address
        block_id = 2_i64
        nonce = DApps::BuildIn::Nonce.new(address, "123", "lastest_hash", block_id, 17, 1609185419188_i64)
        block_factory.blockchain.database.insert_nonce(nonce)
        exec_rest_api(block_factory.rest.__v1_nonces(context("/api/v1/nonces/#{address}/#{block_id}"), {address: address, block_id: block_id})) do |result|
          result["status"].to_s.should eq("success")
          DApps::BuildIn::Nonce.from_json(result["result"][0].to_json).should eq(nonce)
        end
      end
    end
  end

  describe "__v1_pending_nonces" do
    it "should return pending nonces for an address" do
      with_factory do |block_factory, _|
        address = block_factory.node_wallet.address
        miner_nonce = MinerNonce.new("123").with_address(address).with_timestamp(1609185419188_i64)
        MinerNoncePool.add(miner_nonce)
        exec_rest_api(block_factory.rest.__v1_pending_nonces(context("/api/v1/nonces/pending/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          nonce = result["result"][0]
          nonce["address"].should eq(address)
          nonce["nonce"].should eq("123")
          nonce["block_id"].should eq(2_i64)
          nonce["timestamp"].should eq(1609185419188_i64)
        end
      end
    end
  end

  describe "__v1_transaction" do
    it "should create a signed transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = {"transaction" => transaction_factory.make_send(100_i64)}.to_json
        body = IO::Memory.new(transaction)
        exec_rest_api(block_factory.rest.__v1_transaction(context("/api/v1/node/node_id", "POST", body), no_params)) do |result|
          result["status"].to_s.should eq("success")
          Transaction.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_transaction_unsigned" do
    it "should create a unsigned transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction_id = Transaction.create_id
        unsigned_transaction = TransactionDecimal.new(
          transaction_id,
          "send", # action
          [a_decimal_sender(transaction_factory.sender_wallet, "1")],
          [a_decimal_recipient(transaction_factory.recipient_wallet, "1")],
          [] of Transaction::Asset,
          [] of Transaction::Module,
          [] of Transaction::Input,
          [] of Transaction::Output,
          "",            # linked
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          0,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )
        body = IO::Memory.new(unsigned_transaction.to_json)
        exec_rest_api(block_factory.rest.__v1_transaction_unsigned(context("/api/v1/node/node_id", "POST", body), no_params)) do |result|
          result["status"].to_s.should eq("success")
          Transaction.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_assets_id" do
    it "should return the asset details for supplied asset_id" do
      with_factory do |block_factory, transaction_factory|
        asset_id = Transaction::Asset.create_id
        sender_wallet = transaction_factory.sender_wallet

        transaction1 = transaction_factory.make_asset(
          "AXNT",
          "create_asset",
          [a_sender(sender_wallet, 0_i64, 0_i64)],
          [a_recipient(sender_wallet, 0_i64)],
          [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
        )

        block_factory.add_slow_block([transaction1]).add_slow_blocks(4)

        exec_rest_api(block_factory.rest.__v1_assets_id(context("/api/v1/assets/#{asset_id}"), {asset_id: asset_id})) do |result|
          result["status"].to_s.should eq("success")
          asset = Transaction::Asset.from_json(result["result"]["asset"].to_json)
          asset.asset_id.should eq(asset_id)
        end
      end
    end
    it "should return not found for supplied asset_id" do
      with_factory do |block_factory, _|
        asset_id = Transaction::Asset.create_id

        exec_rest_api(block_factory.rest.__v1_assets_id(context("/api/v1/assets/#{asset_id}"), {asset_id: asset_id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].should eq("not found")
          result["result"]["asset"].should eq(nil)
        end
      end
    end
  end

  describe "__v1_assets_address" do
    it "should return paginated asset details for supplied address" do
      with_factory do |block_factory, transaction_factory|
        sender_wallet = transaction_factory.sender_wallet

        txns = (0..10).to_a.flat_map do
          asset_id = Transaction::Asset.create_id
          [create_asset(asset_id, transaction_factory, sender_wallet),
           update_asset(asset_id, transaction_factory, sender_wallet)]
        end
        block_factory.add_slow_block(txns).add_slow_blocks(4)

        exec_rest_api(block_factory.rest.__v1_assets_address(context("/api/v1/assets/address/#{sender_wallet.address}"), {address: sender_wallet.address})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"]["assets"].as_a.map(&.["asset"]).to_json
          Array(Transaction::Asset).from_json(data).size.should eq(11)
        end
      end
    end
  end

  describe "__v1_asset_create_unsigned" do
    it "should create an unsigned asset payload" do
      with_factory do |block_factory, transaction_factory|
        sender_wallet = transaction_factory.sender_wallet

        data = {
          address:        sender_wallet.address,
          public_key:     sender_wallet.public_key,
          name:           "name",
          description:    "desc",
          media_location: "http://location/a",
          quantity:       1,
          kind:           "FAST",
        }

        body = IO::Memory.new(data.to_json)
        exec_rest_api(block_factory.rest.__v1_asset_create_unsigned(context("/api/v1/assets/create/unsigned", "POST", body), no_params)) do |result|
          result["status"].should eq("success")
          transaction = Transaction.from_json(result["result"].to_json)
          asset = transaction.assets.first
          asset.name.should eq("name")
          asset.description.should eq("desc")
          asset.media_location.should eq("http://location/a")
          asset.media_hash.should eq("")
          asset.quantity.should eq(1)
          asset.terms.should eq("")
          asset.version.should eq(1)
          asset.locked.to_s.should eq("UNLOCKED")
        end
      end
    end
  end

  describe "__v1_asset_update_unsigned" do
    it "should create an update unsigned asset payload" do
      with_factory do |block_factory, transaction_factory|
        asset_id = Transaction::Asset.create_id
        sender_wallet = transaction_factory.sender_wallet

        block_factory.add_slow_block([create_asset(asset_id, transaction_factory, sender_wallet)]).add_slow_blocks(4)

        data = {
          address:        sender_wallet.address,
          public_key:     sender_wallet.public_key,
          asset_id:       asset_id,
          name:           "updated_name",
          description:    "updated_desc",
          media_location: "http://somewhere/else",
          quantity:       2,
          locked:         "LOCKED",
          kind:           "FAST",
        }

        body = IO::Memory.new(data.to_json)
        exec_rest_api(block_factory.rest.__v1_asset_update_unsigned(context("/api/v1/assets/update/unsigned", "POST", body), no_params)) do |result|
          result["status"].should eq("success")
          transaction = Transaction.from_json(result["result"].to_json)
          asset = transaction.assets.first
          asset.name.should eq("updated_name")
          asset.description.should eq("updated_desc")
          asset.media_location.should eq("http://somewhere/else")
          asset.media_hash.should eq("media_hash_#{asset_id}")
          asset.quantity.should eq(2)
          asset.terms.should eq("terms")
          asset.version.should eq(2)
          asset.locked.to_s.should eq("LOCKED")
        end
      end
    end
    it "should return error for create an update unsigned asset payload when asset not found" do
      with_factory do |block_factory, transaction_factory|
        asset_id = Transaction::Asset.create_id
        sender_wallet = transaction_factory.sender_wallet

        data = {
          address:        sender_wallet.address,
          public_key:     sender_wallet.public_key,
          asset_id:       asset_id,
          name:           "updated_name",
          description:    "updated_desc",
          media_location: "http://somewhere/else",
          quantity:       2,
          locked:         "LOCKED",
          kind:           "FAST",
        }

        body = IO::Memory.new(data.to_json)
        exec_rest_api(block_factory.rest.__v1_asset_update_unsigned(context("/api/v1/assets/update/unsigned", "POST", body), no_params)) do |result|
          result["status"].should eq("error")
          result["reason"].should eq("asset #{asset_id} not found")
        end
      end
    end
    it "should create an update unsigned asset payload" do
      with_factory do |block_factory, transaction_factory|
        asset_id = Transaction::Asset.create_id
        sender_wallet = transaction_factory.sender_wallet

        lock_asset = transaction_factory.make_asset(
          "AXNT",
          "update_asset",
          [a_sender(sender_wallet, 0_i64, 0_i64)],
          [a_recipient(sender_wallet, 0_i64)],
          [Transaction::Asset.new(asset_id, "name_#{asset_id}", "description_#{asset_id}", "media_location_#{asset_id}", "media_hash_#{asset_id}", 2, "terms", AssetAccess::LOCKED, 2, __timestamp)]
        )

        block_factory.add_slow_block([create_asset(asset_id, transaction_factory, sender_wallet), lock_asset]).add_slow_blocks(4)

        data = {
          address:        sender_wallet.address,
          public_key:     sender_wallet.public_key,
          asset_id:       asset_id,
          name:           "updated_name",
          description:    "updated_desc",
          media_location: "http://somewhere/else",
          quantity:       2,
          locked:         "LOCKED",
          kind:           "FAST",
        }

        body = IO::Memory.new(data.to_json)
        exec_rest_api(block_factory.rest.__v1_asset_update_unsigned(context("/api/v1/assets/update/unsigned", "POST", body), no_params)) do |result|
          result["status"].should eq("error")
          result["reason"].should eq("asset #{asset_id} is already locked so no updates are possible")
        end
      end
    end
  end
  describe "__v1_asset_send_unsigned" do
    it "should create a send unsigned asset payload" do
      with_factory do |block_factory, transaction_factory|
        asset_id = Transaction::Asset.create_id
        sender_wallet = transaction_factory.sender_wallet
        recipient_wallet = transaction_factory.recipient_wallet
        block_factory.add_slow_block([create_asset(asset_id, transaction_factory, sender_wallet)]).add_slow_blocks(4)

        data = {
          to_address:   recipient_wallet.address,
          from_address: sender_wallet.address,
          public_key:   sender_wallet.public_key,
          asset_id:     asset_id,
          amount:       1,
          kind:         "FAST",
        }

        body = IO::Memory.new(data.to_json)
        exec_rest_api(block_factory.rest.__v1_asset_send_unsigned(context("/api/v1/assets/send/unsigned", "POST", body), no_params)) do |result|
          result["status"].should eq("success")
          transaction = Transaction.from_json(result["result"].to_json)
          transaction.action.should eq("send_asset")
          transaction.senders.first.asset_id.should eq(asset_id)
          transaction.senders.first.asset_quantity.should eq(1)
          transaction.recipients.first.asset_id.should eq(asset_id)
          transaction.recipients.first.asset_quantity.should eq(1)
        end
      end
    end
  end
end

private def create_asset(asset_id, transaction_factory, sender_wallet) : Transaction
  transaction_factory.make_asset(
    "AXNT",
    "create_asset",
    [a_sender(sender_wallet, 0_i64, 0_i64)],
    [a_recipient(sender_wallet, 0_i64)],
    [Transaction::Asset.new(asset_id, "name_#{asset_id}", "description_#{asset_id}", "media_location_#{asset_id}", "media_hash_#{asset_id}", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
  )
end

private def update_asset(asset_id, transaction_factory, sender_wallet) : Transaction
  transaction_factory.make_asset(
    "AXNT",
    "update_asset",
    [a_sender(sender_wallet, 0_i64, 0_i64)],
    [a_recipient(sender_wallet, 0_i64)],
    [Transaction::Asset.new(asset_id, "name_#{asset_id}", "description_#{asset_id}", "media_location_#{asset_id}", "media_hash_#{asset_id}", 2, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
  )
end

struct DomainResult
  include JSON::Serializable
  property domain_name : String
  property address : String
  property status : Int64
  property price : String
end

struct NodeResult
  include JSON::Serializable
  property id : String
  property host : String
  property port : Int64
  property ssl : Bool
  property type : String
  property is_private : Bool
end

struct NodesResult
  include JSON::Serializable
  property successor_list : Array(String)
  property predecessor : Nil
  property private_nodes : Array(String)
end

def context(url : String, method : String = "GET", body : IO = IO::Memory.new)
  MockContext.new(method, url, body).unsafe_as(HTTP::Server::Context)
end

def no_params
  {} of String => String
end
