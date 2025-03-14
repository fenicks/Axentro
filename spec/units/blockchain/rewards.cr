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

include Units::Utils
include Axentro::Core
include Axentro::Core::TransactionModels
include ::Axentro::Common::Denomination
include ::Axentro::Core::NodeComponents
include Hashes

TOTAL_BLOCK_REWARD = 1200000000_i64
TOTAL_BLOCK_LIMIT  =  8_000_000_i64

describe Blockchain do
  Spec.before_each {
    with_factory do |block_factory, _|
      block_factory.blockchain.miner_nonce_pool.clear_all
    end
  }

  it "should calculate the block rewards for a single miner" do
    with_factory do |block_factory, _|
      miner1 = Miner.new(MockWebSocket.new, "miner1", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      coinbase_amount = block_factory.blockchain.coinbase_slow_amount(0, [] of Transaction)
      with_miner_nonces(miner1, ["1", "2"], "Miner 1", block_factory)
      transaction = block_factory.blockchain.create_coinbase_slow_transaction(coinbase_amount, 0_i64, [miner1])

      node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address).amount
      miner1_reward = get_recipient_for(transaction.recipients, "Miner 1").amount

      node_reward.should eq(300000000_i64)
      as_percentage(node_reward).should eq(25)

      miner1_reward.should eq(900000000_i64)
      as_percentage(miner1_reward).should eq(75)

      (node_reward + miner1_reward).should eq(TOTAL_BLOCK_REWARD)
    end
  end

  it "should calculate the block rewards for multiple miners" do
    with_factory do |block_factory, _|
      miner1 = Miner.new(MockWebSocket.new, "miner1", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      miner2 = Miner.new(MockWebSocket.new, "miner2", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      miner3 = Miner.new(MockWebSocket.new, "miner3", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      coinbase_amount = block_factory.blockchain.coinbase_slow_amount(0, [] of Transaction)
      with_miner_nonces(miner1, ["1", "2"], "Miner 1", block_factory)
      with_miner_nonces(miner2, ["1", "2"], "Miner 2", block_factory)
      with_miner_nonces(miner3, ["1", "2"], "Miner 3", block_factory)
      transaction = block_factory.blockchain.create_coinbase_slow_transaction(coinbase_amount, 0_i64, [miner1, miner2, miner3])

      node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address).amount
      miner1_reward = get_recipient_for(transaction.recipients, "Miner 1").amount
      miner2_reward = get_recipient_for(transaction.recipients, "Miner 2").amount
      miner3_reward = get_recipient_for(transaction.recipients, "Miner 3").amount

      node_reward.should eq(300000000_i64)
      as_percentage(node_reward).should eq(25)

      miner1_reward.should eq(300000000_i64)
      as_percentage(miner1_reward).should eq(25)

      miner2_reward.should eq(300000000_i64)
      as_percentage(miner2_reward).should eq(25)

      miner3_reward.should eq(300000000_i64)
      as_percentage(miner3_reward).should eq(25)

      (node_reward + miner1_reward + miner2_reward + miner3_reward).should eq(TOTAL_BLOCK_REWARD)
    end
  end

  it "should reward miners according to their contribution (node always gets 25%)" do
    assert_reward_distribution(1, 2, 25, 50)
    assert_reward_distribution(1, 3, 19, 56)
    assert_reward_distribution(1, 4, 15, 60)
    assert_reward_distribution(1, 5, 13, 63)
    assert_reward_distribution(1, 6, 11, 64)
    assert_reward_distribution(1, 7, 9, 66)
    assert_reward_distribution(1, 70, 1, 74)
    assert_reward_distribution(1, 150, 0, 75) # miner 1 got no reward
  end

  it "should not allocate rewards if the total supply has been reached and there are no senders in the transactions" do
    with_factory do |block_factory, _|
      miner1 = Miner.new(MockWebSocket.new, "miner1", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      with_miner_nonces(miner1, ["1", "2"], "Miner 1", block_factory)
      coinbase_amount = block_factory.blockchain.coinbase_slow_amount(TOTAL_BLOCK_LIMIT, [] of Transaction)
      transaction = block_factory.blockchain.create_coinbase_slow_transaction(coinbase_amount, 0_i64, [miner1])
      transaction.recipients.should be_empty
    end
  end

  it "should allocate rewards from fees if the total supply has been reached and there are senders in the transactions" do
    with_factory do |block_factory, transaction_factory|
      miner1 = Miner.new(MockWebSocket.new, "miner1", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
      transactions = [transaction_factory.make_send(2000_i64), transaction_factory.make_send(9000_i64)]
      total_reward = transactions.flat_map(&.senders).map(&.fee).reduce(0) { |total, fee| total + fee }
      with_miner_nonces(miner1, ["1", "2"], "Miner 1", block_factory)

      coinbase_amount = block_factory.blockchain.coinbase_slow_amount(TOTAL_BLOCK_LIMIT + 1, transactions)
      transaction = block_factory.blockchain.create_coinbase_slow_transaction(coinbase_amount, 0_i64, [miner1])

      node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address).amount
      miner1_reward = get_recipient_for(transaction.recipients, "Miner 1").amount

      node_reward.should eq(5000_i64)
      as_percentage(node_reward, total_reward).should eq(25)

      miner1_reward.should eq(15000_i64)
      as_percentage(miner1_reward, total_reward).should eq(75)

      (node_reward + miner1_reward).should eq(total_reward)
    end
  end
end

def with_miner_nonces(miner, nonce_values : Array(String), miner_address, block_factory)
  miner_nonces = nonce_values.map do |nv|
    MinerNonce.from(nv).with_mid(miner.mid).with_address(miner_address)
  end
  miner_nonces.each { |mn| block_factory.blockchain.miner_nonce_pool.add(mn) }
end

def assert_reward_distribution(nonces1, nonces2, expected_percent_1, expected_percent_2)
  with_factory do |block_factory, _|
    miner1 = Miner.new(MockWebSocket.new, "miner1", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
    miner2 = Miner.new(MockWebSocket.new, "miner2", block_factory.blockchain.mining_block.difficulty, "127.0.0.1", 0, "name", "address")
    coinbase_amount = block_factory.blockchain.coinbase_slow_amount(0, [] of Transaction)

    with_miner_nonces(miner1, (1..nonces1).map(&.to_s), "Miner 1", block_factory)
    with_miner_nonces(miner2, (1..nonces2).map(&.to_s), "Miner 2", block_factory)

    transaction = block_factory.blockchain.create_coinbase_slow_transaction(coinbase_amount, 0_i64, [miner1, miner2])

    node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address).amount
    miner1_reward = get_recipient_for(transaction.recipients, "Miner 1").amount
    miner2_reward = get_recipient_for(transaction.recipients, "Miner 2").amount

    as_percentage(node_reward).should eq(25)
    as_percentage(miner1_reward).should eq(expected_percent_1)
    as_percentage(miner2_reward).should eq(expected_percent_2)

    (node_reward + miner1_reward + miner2_reward).should eq(TOTAL_BLOCK_REWARD)
  end
end

def get_recipient_for(recipients, address)
  recipients.find(&.address.==(address)).not_nil!
end

def as_percentage(percent_of, total = TOTAL_BLOCK_REWARD)
  ((percent_of.to_f64 / total.to_f64) * 100).round.to_i32
end
