%%% -*- erlang -*-
%%%
%%% MIT License
%%%
%%% Copyright (c) 2014-2016 Ilya Khaprov <ilya.khaprov@publitechs.com>

-module(ssl_verify_fingerprint).
-export([verify_fun/3]).

-import(ssl_verify_util, [hexstr_to_bin/1,
                          bin_to_hexstr/1]).

-ifdef(TEST).
-export([verify_cert_fingerprint/2]).
-endif.

-include_lib("public_key/include/public_key.hrl").

verify_cert_fingerprint(Cert, Fingerprint, FingerprintAlgorithm) ->
  CertBinary = public_key:pkix_encode('OTPCertificate', Cert, 'otp'),
  Hash = crypto:hash(FingerprintAlgorithm, CertBinary),
  case Hash of
    Fingerprint ->
      {valid, bin_to_hexstr(Fingerprint)};
    _ ->
      {fail, fingerprint_no_match}
  end.

verify_cert_fingerprint(Cert, CheckFingerprint) ->
  {FingerprintAlgorithm, Fingerprint} = CheckFingerprint,
  case hexstr_to_bin(Fingerprint) of
    invalid -> {fail, invalid_fingerprint};
    FingerprintB -> verify_cert_fingerprint(Cert, FingerprintB, FingerprintAlgorithm)
  end.

-spec verify_fun(Cert :: #'OTPCertificate'{},
                 Event :: {bad_cert, Reason :: atom() | {revoked, atom()}} |
                          {extension, #'Extension'{}}, InitialUserState :: term()) ->
                    {valid, UserState :: term()} | {valid_peer, UserState :: term()} |
                    {fail, Reason :: term()} | {unknown, UserState :: term()}.
verify_fun(_, {bad_cert, _}, UserState) ->
  {valid, UserState};
verify_fun(_, {extension, _}, UserState) ->
  {unknown, UserState};
verify_fun(_, valid, UserState) ->
  {valid, UserState};
verify_fun(Cert, valid_peer, UserState) ->
  CheckFingerprint = proplists:get_value(check_fingerprint, UserState),
  case CheckFingerprint of
    undefined -> {valid, UserState};
    _ ->  verify_cert_fingerprint(Cert, CheckFingerprint)
  end.
