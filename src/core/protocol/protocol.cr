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
require "../blockchain/rewards/models"
require "../node/components/slow_sync"

module ::Axentro::Core::Protocol
  struct Transport
    include MessagePack::Serializable
    property type : Int32
    property content : String

    def initialize(@type, @content); end
  end

  ######################################
  # MINER
  ######################################

  M_TYPE_MINER_HANDSHAKE = 0x0001

  struct MContentMinerHandshake
    include JSON::Serializable
    property version : String
    property address : String
    property mid : String
  end

  M_TYPE_MINER_HANDSHAKE_ACCEPTED = 0x0002

  struct MContentMinerHandshakeAccepted
    include JSON::Serializable
    property version : String
    property block : Block
    property difficulty : Int32
  end

  M_TYPE_MINER_HANDSHAKE_REJECTED = 0x0003

  struct MContentMinerHandshakeRejected
    include JSON::Serializable
    property reason : String
  end

  M_TYPE_MINER_FOUND_NONCE = 0x0004

  struct MContentMinerFoundNonce
    include JSON::Serializable
    property nonce : MinerNonce
  end

  M_TYPE_MINER_BLOCK_UPDATE = 0x0005

  struct MContentMinerBlockUpdate
    include JSON::Serializable
    property block : Block
    property difficulty : Int32
  end

  M_TYPE_MINER_BLOCK_DIFFICULTY_ADJUST = 0x0006

  struct MContentMinerBlockDifficultyAdjust
    include JSON::Serializable
    property block : Block
    property difficulty : Int32
    property reason : String
  end

  M_TYPE_MINER_BLOCK_INVALID = 0x0007

  struct MContentMinerBlockInvalid
    include JSON::Serializable
    property block : Block
    property difficulty : Int32
    property reason : String
  end

  M_TYPE_MINER_EXCEED_RATE = 0x0008

  struct MContentMinerExceedRate
    include JSON::Serializable
    property reason : String
    property remaining_duration : Int32
  end

  M_TYPE_MINER_INSUFFICIENT_DURATION = 0x0009

  struct MContentMinerInsufficientDuration
    include JSON::Serializable
    property reason : String
    property connected_duration : Int64
  end

  ######################################
  # CLIENT
  ######################################

  M_TYPE_CLIENT_HANDSHAKE = 0x1001

  struct MContentClientHandshake
    include JSON::Serializable
    property public_key : String
  end

  M_TYPE_CLIENT_SALT = 0x1005

  struct MContentClientSalt
    include JSON::Serializable
    property salt : String
  end

  M_TYPE_CLIENT_UPGRADE = 0x1006

  struct MContentClientUpgrade
    include JSON::Serializable
    property address : String
    property public_key : String
    property signature : String
  end

  M_TYPE_CLIENT_HANDSHAKE_ACCEPTED = 0x1002

  struct MContentClientHandshakeAccepted
    include JSON::Serializable
    property address : String
  end

  M_TYPE_CLIENT_CONTENT = 0x1003

  struct MContentClientContent
    include JSON::Serializable
    property action : String
    property from : String
    property content : String
  end

  #
  # Content structure of content of MContentClientContent
  #
  struct MContentClientMessage
    include JSON::Serializable
    property to : String
    property message : String
  end

  struct MContentClientAmount
    include JSON::Serializable
    property token : String
    property confirmation : Int32
  end

  #
  # Used in clients
  #
  M_TYPE_CLIENT_RECEIVE = 0x1004

  struct MContentClientReceive
    include JSON::Serializable
    property from : String
    property to : String
    property content : String
  end

  ######################################
  # CHORD
  ######################################

  M_TYPE_CHORD_JOIN = 0x0011

  struct MContentChordJoin
    include JSON::Serializable
    property version : String
    property context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_PRIVATE = 0x0012

  struct MContentChordJoinPrivate
    include JSON::Serializable
    property version : String
    property context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED = 0x0013

  struct MContentChordJoinPrivateAccepted
    include JSON::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x0014

  struct MContentChordFoundSuccessor
    include JSON::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x0015

  struct MContentChordSearchSuccessor
    include JSON::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x0016

  struct MContentChordStabilizeAsSuccessor
    include JSON::Serializable
    property predecessor_context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x0017

  struct MContentChordStabilizeAsPredecessor
    include JSON::Serializable
    property successor_context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_REJECTED = 0x0018

  struct MContentChordJoinRejected
    include JSON::Serializable
    property reason : String
  end

  M_TYPE_CHORD_BROADCAST_NODE_JOINED = 0x0019

  struct MContentChordBroadcastNodeJoined
    include JSON::Serializable
    property nodes : Array(Core::NodeComponents::Chord::NodeContext)
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_RECONNECT = 0x0020

  M_TYPE_CHORD_RECONNECT_PRIVATE = 0x0021

  ######################################
  # NODE
  ######################################

  M_TYPE_NODE_BROADCAST_TRANSACTION = 0x0101

  struct MContentNodeBroadcastTransaction
    include JSON::Serializable
    property transaction : Transaction
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_BROADCAST_BLOCK = 0x0102

  struct MContentNodeBroadcastBlock
    include JSON::Serializable
    property block : Block
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_REQUEST_STREAM_SLOW_BLOCK = 0x0120

  struct MContentNodeRequestStreamSlowBlock
    include JSON::Serializable
    property start_slow : Int64
  end

  M_TYPE_NODE_RECEIVE_STREAM_SLOW_BLOCK = 0x0121

  struct MContentNodeReceiveStreamSlowBlock
    include JSON::Serializable
    property block : Block
    property start_slow : Int64
    property target_slow : Int64
    property total_size : Int32
  end

  M_TYPE_NODE_REQUEST_STREAM_FAST_BLOCK = 0x0122

  struct MContentNodeRequestStreamFastBlock
    include JSON::Serializable
    property start_fast : Int64
  end

  M_TYPE_NODE_RECEIVE_STREAM_FAST_BLOCK = 0x0123

  struct MContentNodeReceiveStreamFastBlock
    include JSON::Serializable
    property block : Block
    property start_fast : Int64
    property target_fast : Int64
    property total_size : Int32
  end

  M_TYPE_NODE_REQUEST_TRANSACTIONS = 0x0106

  struct MContentNodeRequestTransactions
    include JSON::Serializable
    property transactions : Array(Transaction)
  end

  M_TYPE_NODE_RECEIVE_TRANSACTIONS = 0x0107

  struct MContentNodeReceiveTransactions
    include JSON::Serializable
    property transactions : Array(Transaction)
  end

  M_TYPE_NODE_SEND_CLIENT_CONTENT = 0x0108

  struct MContentNodeSendClientContent
    include JSON::Serializable
    property content : String
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_BROADCAST_MINER_NONCE = 0x0110

  struct MContentNodeBroadcastMinerNonce
    include JSON::Serializable
    property nonce : MinerNonce
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_REQUEST_MINER_NONCES = 0x0111

  struct MContentNodeRequestMinerNonces
    include JSON::Serializable
    property nonces : Array(MinerNonce)
  end

  M_TYPE_NODE_RECEIVE_MINER_NONCES = 0x0112

  struct MContentNodeReceiveMinerNonces
    include JSON::Serializable
    property nonces : Array(MinerNonce)
  end

  M_TYPE_NODE_BROADCAST_REJECT_BLOCK = 0x0119

  struct MContentNodeBroadcastRejectBlock
    include JSON::Serializable
    property reject_block : RejectBlock
    property from : Core::NodeComponents::Chord::NodeContext
  end

  ######################################
  # Blockchain's setup phase
  ######################################

  enum SetupPhase
    NONE
    BLOCKCHAIN_VALIDATING
    CONNECTING_NODES
    BLOCKCHAIN_SYNCING
    TRANSACTION_SYNCING
    MINER_NONCE_SYNCING
    PRE_DONE
    DONE
  end

  include ::Axentro::Core
  include ::Axentro::Core::NodeComponents
  include ::Axentro::Core::NonceModels
end
