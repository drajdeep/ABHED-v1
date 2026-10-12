# Copyright 2026 Rajdeep Das, Institute of Engineering & Management (IEM), Kolkata, India
# SPDX-License-Identifier: Apache-2.0
# Part of ABHED-v1. See the LICENSE and NOTICE files for terms and attribution.
"""Lab topology. IPs can be overridden with env vars (used for loopback smoke tests)."""
import os

ROOT_IP = os.environ.get("ROOT_IP", "172.30.53.10")
TLD_IP = os.environ.get("TLD_IP", "172.30.53.20")
SLD_IP = os.environ.get("SLD_IP", "172.30.53.30")
RESOLVER_IP = os.environ.get("RESOLVER_IP", "172.30.53.53")
RESOLVER_API = os.environ.get("RESOLVER_API", f"http://{RESOLVER_IP}:8082")
RESOLVER_API_KEY = os.environ.get("RESOLVER_API_KEY", "labkey")

ROOT_NS = "a.root-servers.lab."
TLD_NS = "ns1.nic.lab."
SLD_NS = "ns1.iem.lab."

TTL = 3600
DATASETS = {"small": 100, "medium": 1000, "large": 10000}   # host RRsets in iem.lab
