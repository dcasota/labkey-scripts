"""Credential resolution and TLS policy.

These tests never touch the network. They exist because the failure modes they
cover are silent: a credential that leaks into a log, or TLS verification
disabled against a host that is not this machine.
"""
from __future__ import annotations

import pytest

from osm.labkey.config import ConfigError, LabKeyConfig, _is_loopback, load_config


def env(**kw: str) -> dict[str, str]:
    return dict(kw)


# --- credential resolution ---------------------------------------------------

def test_api_key_alone_is_sufficient():
    cfg = load_config(env(LK_APIKEY="0" * 64))
    assert cfg.uses_api_key
    assert cfg.auth_headers() == {"apikey": "0" * 64}


def test_user_and_password_are_sufficient():
    cfg = load_config(env(LK_USER="someone", LK_PASSWORD="unused-in-test"))
    assert not cfg.uses_api_key
    assert cfg.auth_headers() == {}


def test_api_key_takes_precedence_over_password():
    """Matches the user's shell scripts: an API key wins, because it can carry
    a restriction role and be revoked independently."""
    cfg = load_config(env(LK_APIKEY="k" * 64, LK_USER="someone", LK_PASSWORD="x"))
    assert cfg.uses_api_key


@pytest.mark.parametrize(
    "environment, expected_missing",
    [
        ({}, ["LK_USER", "LK_PASSWORD"]),
        ({"LK_USER": "someone"}, ["LK_PASSWORD"]),
        ({"LK_PASSWORD": "x"}, ["LK_USER"]),
        ({"LK_USER": "  ", "LK_PASSWORD": "x"}, ["LK_USER"]),
    ],
)
def test_missing_credentials_abort_and_name_the_variable(environment, expected_missing):
    """A missing credential must fail immediately and say which one, rather than
    producing an opaque 401 later."""
    with pytest.raises(ConfigError) as excinfo:
        load_config(environment)
    message = str(excinfo.value)
    for name in expected_missing:
        assert name in message
    assert "LK_APIKEY" in message


def test_no_credential_has_a_default():
    """The specific failure this guards against: build-labkey-community.sh
    defaults a password to a working value, so nobody notices."""
    with pytest.raises(ConfigError):
        load_config({})


# --- credential disclosure ---------------------------------------------------

def test_repr_never_discloses_the_password():
    cfg = load_config(env(LK_USER="someone", LK_PASSWORD="hunter2-should-not-appear"))
    assert "hunter2-should-not-appear" not in repr(cfg)


def test_repr_never_discloses_the_api_key():
    cfg = load_config(env(LK_APIKEY="deadbeef" * 8))
    assert "deadbeef" not in repr(cfg)


def test_describe_names_the_auth_mode_but_not_the_secret():
    cfg = load_config(env(LK_APIKEY="s3cret-key-value", LK_URL="https://example.test"))
    described = cfg.describe()
    assert "api-key" in described
    assert "s3cret-key-value" not in described

    cfg = load_config(env(LK_USER="someone", LK_PASSWORD="s3cret-password"))
    described = cfg.describe()
    assert "someone" in described
    assert "s3cret-password" not in described


# --- TLS policy --------------------------------------------------------------

@pytest.mark.parametrize("host", ["127.0.0.1", "localhost", "::1", "127.0.0.53"])
def test_loopback_hosts_are_recognised(host):
    assert _is_loopback(host)


@pytest.mark.parametrize("host", ["labkey.example.org", "10.0.0.5", "192.168.1.4", ""])
def test_non_loopback_hosts_are_not_recognised(host):
    assert not _is_loopback(host)


def test_tls_verification_is_skipped_for_loopback_by_default():
    """The deployment terminates TLS with a self-signed certificate, so
    verifying loopback always fails."""
    cfg = load_config(env(LK_URL="https://127.0.0.1:8443", LK_APIKEY="k"))
    assert cfg.verify_tls is False


def test_tls_verification_is_required_for_a_remote_host_by_default():
    """The important denial: a real network destination must verify unless the
    operator opts out deliberately."""
    cfg = load_config(env(LK_URL="https://labkey.example.org", LK_APIKEY="k"))
    assert cfg.verify_tls is True


def test_lk_insecure_can_disable_verification_for_a_remote_host():
    cfg = load_config(env(LK_URL="https://labkey.example.org", LK_APIKEY="k", LK_INSECURE="1"))
    assert cfg.verify_tls is False


def test_lk_insecure_zero_forces_verification_even_on_loopback():
    cfg = load_config(env(LK_URL="https://127.0.0.1:8443", LK_APIKEY="k", LK_INSECURE="0"))
    assert cfg.verify_tls is True


# --- URL handling ------------------------------------------------------------

def test_auto_context_probes_root_then_labkey():
    cfg = load_config(env(LK_APIKEY="k", LK_URL="https://host:8443/"))
    assert cfg.base_url_candidates() == ["https://host:8443", "https://host:8443/labkey"]


def test_explicit_context_is_used_verbatim():
    cfg = load_config(env(LK_APIKEY="k", LK_URL="https://host:8443", LK_CONTEXT="/labkey"))
    assert cfg.base_url_candidates() == ["https://host:8443/labkey"]


def test_empty_context_means_the_root():
    cfg = load_config(env(LK_APIKEY="k", LK_URL="https://host:8443", LK_CONTEXT="/"))
    assert cfg.base_url_candidates() == ["https://host:8443"]


@pytest.mark.parametrize("url", ["ftp://host", "not-a-url", "https://"])
def test_a_malformed_url_is_rejected(url):
    with pytest.raises(ConfigError):
        LabKeyConfig(url=url, api_key="k")


@pytest.mark.parametrize("raw", ["nope", "-1", "0"])
def test_a_bad_timeout_is_rejected(raw):
    with pytest.raises(ConfigError):
        load_config(env(LK_APIKEY="k", LK_TIMEOUT=raw))
