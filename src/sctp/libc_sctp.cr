@[Link("sctp")]

lib LibC

  IPPROTO_SCTP = 132

  SCTP_RTOINFO = 0
  SCTP_ASSOCINFO = 1
  SCTP_INITMSG = 2
  SCTP_NODELAY = 3		# Get/set nodelay option.
  SCTP_AUTOCLOSE = 4
  SCTP_SET_PEER_PRIMARY_ADDR = 5
  SCTP_PRIMARY_ADDR = 6
  SCTP_ADAPTATION_LAYER = 7
  SCTP_DISABLE_FRAGMENTS = 8
  SCTP_PEER_ADDR_PARAMS = 9
  SCTP_DEFAULT_SEND_PARAM = 10
  SCTP_EVENTS = 11
  SCTP_I_WANT_MAPPED_V4_ADDR = 12	# Turn on/off mapped v4 addresses
  SCTP_MAXSEG = 13		# Get/set maximum fragment.
  SCTP_STATUS = 14
  SCTP_GET_PEER_ADDR_INFO = 15
  SCTP_DELAYED_ACK_TIME = 16
  SCTP_DELAYED_ACK = SCTP_DELAYED_ACK_TIME
  SCTP_DELAYED_SACK = SCTP_DELAYED_ACK_TIME
  SCTP_CONTEXT = 17
  SCTP_FRAGMENT_INTERLEAVE = 18
  SCTP_PARTIAL_DELIVERY_POINT = 19 # Set/Get partial delivery point
  SCTP_MAX_BURST = 20		# Set/Get max burst
  SCTP_AUTH_CHUNK = 21	# Set only: add a chunk type to authenticate
  SCTP_HMAC_IDENT = 22
  SCTP_AUTH_KEY = 23
  SCTP_AUTH_ACTIVE_KEY = 24
  SCTP_AUTH_DELETE_KEY = 25
  SCTP_PEER_AUTH_CHUNKS = 26	# Read only
  SCTP_LOCAL_AUTH_CHUNKS = 27	# Read only
  SCTP_GET_ASSOC_NUMBER = 28	# Read only

   # Internal Socket Options. Some of the sctp library functions are
   # implemented using these socket options.

  SCTP_SOCKOPT_BINDX_ADD = 100	# BINDX requests for adding addrs
  SCTP_SOCKOPT_BINDX_REM = 101	# BINDX requests for removing addrs.
  SCTP_SOCKOPT_PEELOFF = 102	# peel off association.
  # Options 104-106 are deprecated and removed. Do not use this space
  SCTP_SOCKOPT_CONNECTX_OLD = 107	# CONNECTX old requests.
  SCTP_GET_PEER_ADDRS = 108		# Get all peer addresss.
  SCTP_GET_LOCAL_ADDRS = 109		# Get all local addresss.
  SCTP_SOCKOPT_CONNECTX = 110		# CONNECTX requests.
  SCTP_SOCKOPT_CONNECTX3 = 111	# CONNECTX requests (updated)

  # SCTP socket option used to read per endpoint association statistics.
  SCTP_GET_ASSOC_STATS = 112      # Read only
  #struct Sockaddr
  #  sa_family : SaFamilyT
  #  sa_data : LibC::Char[14]
  #end
  #alias SaFamilyT = LibC::UShort
  fun sctp_bindx(sd : LibC::Int, addrs : Sockaddr*, addrcnt : LibC::Int, flags : LibC::Int) : LibC::Int
  alias X__S32 = LibC::Int
  alias SctpAssocT = X__S32
  fun sctp_connectx(sd : LibC::Int, addrs : Sockaddr*, addrcnt : LibC::Int, id : SctpAssocT*) : LibC::Int
  fun sctp_peeloff(sd : LibC::Int, assoc_id : SctpAssocT) : LibC::Int
  alias X__SocklenT = LibC::UInt
  #alias SocklenT = X__SocklenT
  fun sctp_opt_info(sd : LibC::Int, id : SctpAssocT, opt : LibC::Int, arg : Void*, size : SocklenT*) : LibC::Int
  fun sctp_getpaddrs(sd : LibC::Int, id : SctpAssocT, addrs : Sockaddr**) : LibC::Int
  fun sctp_freepaddrs(addrs : Sockaddr*) : LibC::Int
  fun sctp_getladdrs(sd : LibC::Int, id : SctpAssocT, addrs : Sockaddr**) : LibC::Int
  fun sctp_freeladdrs(addrs : Sockaddr*) : LibC::Int
  alias Uint32T = LibC::UInt
  alias Uint16T = LibC::UShort
  fun sctp_sendmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, to : Sockaddr*, tolen : SocklenT, ppid : Uint32T, flags : Uint32T, stream_no : Uint16T, timetolive : Uint32T, context : Uint32T) : LibC::Int
  struct SctpSndrcvinfo
    sinfo_stream : X__U16
    sinfo_ssn : X__U16
    sinfo_flags : X__U16
    sinfo_ppid : X__U32
    sinfo_context : X__U32
    sinfo_timetolive : X__U32
    sinfo_tsn : X__U32
    sinfo_cumtsn : X__U32
    sinfo_assoc_id : SctpAssocT
  end
  alias X__U16 = LibC::UShort
  alias X__U32 = LibC::UInt
  fun sctp_send(s : LibC::Int, msg : Void*, len : LibC::SizeT, sinfo : SctpSndrcvinfo*, flags : LibC::Int) : LibC::Int
  fun sctp_recvmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, from : Sockaddr*, fromlen : SocklenT*, sinfo : SctpSndrcvinfo*, msg_flags : LibC::Int*) : LibC::Int
  fun sctp_getaddrlen(family : SaFamilyT) : LibC::Int
end
