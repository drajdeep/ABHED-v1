# ABHED-v1
### Authenticated Benchmarking of Hybrid Encryption-resistant DNSSEC

**Author:** Rajdeep Das, Research Fellow, Institute of Engineering & Management (IEM), Kolkata, India

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Supported by:** IEM-UEM Group · India Internet Foundation (IIFON) · AIORI, Ministry of Electronics and Information Technology (MeitY), Government of India

---

ABHED-v1 is a reproducible, containerised testbed that benchmarks **ML-DSA-44** (FIPS 204) against
**MTL + ML-DSA-44** (Merkle Tree Ladder mode) for DNSSEC zone signing and validation, on a full
delegation chain: **root → lab. → iem.lab.**, an unmodified PowerDNS recursive resolver, and a
separate validating client.

- KSK: ECDSAP256SHA256 (classical). ZSK: ML-DSA-44 (lab alg 200) or ML-DSA-44-MTL-SHAKE-128 (lab alg 201).
- MTL implemented per draft-harvey-cfrg-mtl-mode-09; RRSIG encoding per draft-fregly-dnsop-slh-dsa-mtl-dnssec.
- No changes to DNS server software: authoritative servers run in pre-signed mode, the resolver in
  `process-no-validate` mode; post-quantum validation runs in the client's session-based validator.
- Architecture, MTL mapping and pseudocode: [`docs/DESIGN.md`](docs/DESIGN.md).
  Live demonstration: [`docs/DEMO.md`](docs/DEMO.md).
  Full references: [`docs/TECHNICAL_MANUAL.md`](docs/TECHNICAL_MANUAL.md), [`docs/TESTING_MANUAL.md`](docs/TESTING_MANUAL.md).

| Container | IP | Role |
|---|---|---|
| `root` | 172.30.53.10 | PowerDNS Auth, zone `.` |
| `tld-lab` | 172.30.53.20 | PowerDNS Auth, zone `lab.` |
| `sld-iem` | 172.30.53.30 | PowerDNS Auth, zone `iem.lab.` |
| `resolver` | 172.30.53.53 | PowerDNS Recursor 5.3, lab root hints |
| `client` | 172.30.53.100 | dig, PQC validator, benchmarks |
| `tools` | — | one-shot: signer, offline benchmarks, report |

---

## Step 1 — Install Docker on a fresh Ubuntu (22.04 / 24.04)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git python3 util-linux
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker            # or log out and back in
docker run --rm hello-world
docker compose version
```

## Step 2 — Get the project

```bash
unzip pqc-dnssec-mtl-testbed.zip && cd pqc-dnssec-mtl-testbed
chmod +x tb.sh scripts/*.sh docker/auth/entrypoint.sh
```

## Step 3 — (Recommended) pin the machine for stable numbers

```bash
nproc                                    # need >= 4 for separate cores
sudo apt-get install -y linux-tools-common linux-tools-$(uname -r) || true
sudo cpupower frequency-set -g performance || true
```
Edit `.env` so `AUTH_CPUS`, `RESOLVER_CPUS`, `CLIENT_CPUS/BENCH_CPUS` are different cores. Close other heavy apps.

## Step 4 — Build everything

```bash
./tb.sh setup
```
Builds the images (liboqs 0.16.0 compiled from source, PowerDNS from repo.powerdns.com) and creates
`config/lab-root.hints` from IANA `named.root`. Takes ~5–10 min the first time.

## Step 5 — Bring up the hierarchy (choose a mode)

```bash
./tb.sh sign mtl small        # or: ./tb.sh sign mldsa44 small     (datasets: small | medium | large)
./tb.sh up
./tb.sh test
```
`test` shows: a `dig +dnssec` answer from the client (via the recursor), a `dig +trace` from the lab root
down to `iem.lab`, and a full PQC chain validation ending in `SECURE`.

### Dig from the client container yourself
```bash
docker compose exec client bash
dig +dnssec host00001.iem.lab A          # answer + RRSIG (alg 200 or 201)
dig +dnssec iem.lab DNSKEY               # KSK alg 13 + PQC ZSK
dig +dnssec iem.lab DS                   # DS signed by lab.'s PQC ZSK
dig +trace @172.30.53.10 www.iem.lab     # delegation root -> lab -> iem.lab
dig +dnssec +tcp _mtlladder.iem.lab TXT  # (MTL) full signature = signed ladder
python -m pqcdns.validator host00042.iem.lab www.iem.lab   # full chain-of-trust validation
```

### Switch modes
```bash
./tb.sh sign mldsa44 medium && ./tb.sh reload && ./tb.sh test
```

## Step 6 — Run the benchmarks

Everything at once (≈ 20–40 min, all 3 sizes × 2 modes, 5 trials each):
```bash
./tb.sh bench-all                      # TRIALS=5 QUERIES=300 RUNS=200 by default
```
Or piece by piece:
```bash
./tb.sh env                            # record pinned environment
./tb.sh bench-crypto 5                 # offline sign/verify, 3 sizes, both modes, pinned CPU
./tb.sh sign mtl large && ./tb.sh reload
./tb.sh bench-dns 5 300                # live workload for the zones currently loaded
./tb.sh bench-dns 5 300 --no-ladder-cache   # MTL worst case (no ladder reuse)
./tb.sh bench-endurance 200            # ladder endurance: measured vs analytical
./tb.sh report                         # -> results/REPORT.md + results/figures/*.png
```

## Step 7 — Evolution / backward-compatibility demo (MTL)
```bash
./tb.sh sign mtl small && ./tb.sh reload
./tb.sh demo-evolve
```

## Outputs
| Path | Content |
|---|---|
| `results/REPORT.md` | full report: config, measured results, analytical estimates (separate) |
| `results/figures/` | sign/verify time, RRSIG bytes, DNS bytes, TCP fallbacks, endurance |
| `results/crypto/crypto.json` | offline benchmark raw data (per trial) |
| `results/dns/<mode>_<dataset>/queries.csv` | every query: bytes, TCP, latency, crypto time, ladder fetches |
| `results/endurance/endurance.json` | K measured vs analytic, φ(K,1) |
| `results/env/environment.json` | pinned environment |

Make a PDF of the report:
```bash
sudo apt-get install -y pandoc wkhtmltopdf
cd results && pandoc REPORT.md -o REPORT.pdf --pdf-engine=wkhtmltopdf --resource-path=.
```

## Troubleshooting
| Symptom | Fix |
|---|---|
| `bookworm-auth-50` / `rec-53` not found during build | set `PDNS_AUTH_REPO=auth-49` or `PDNS_REC_REPO=rec-52` in `.env`, rerun `./tb.sh setup` |
| `authoritative servers not ready` | `./tb.sh logs sld-iem`; large ML-DSA zone (~66 MB) needs time to load |
| validator says BOGUS after switching mode | stale resolver cache → `./tb.sh flush` (reload does this automatically) |
| IANA hints download fails | a built-in template is used; lab behaviour is identical |
| `cpuset` errors | your CPU has fewer cores than `.env` asks; edit `.env` |
| Permission denied on `zones/` | `sudo chown -R $USER zones keys results config` |

## Scope
No new cryptography (ML-DSA-44 = liboqs, MTL = published IETF specification), no resolver written from
scratch (PowerDNS Recursor resolves and caches; only PQC signature checks run in the client), no Internet
deployment (isolated lab network, lab-only algorithm numbers 200/201), no new security proof claimed.

## Acknowledgements
This work is supported by the **IEM-UEM Group**, the **India Internet Foundation (IIFON)**, and
**AIORI** under the **Ministry of Electronics and Information Technology (MeitY), Government of India**.
The testbed builds on open-source software: liboqs (Open Quantum Safe), PowerDNS, dnspython,
pycryptodome and cryptography, and on the openly published Merkle Tree Ladder mode Internet-Drafts.

## Citation
If you use ABHED-v1 in academic work, please cite:
```bibtex
@software{das2026abhed,
  author = {Das, Rajdeep},
  title  = {{ABHED-v1}: Authenticated Benchmarking of Hybrid Encryption-resistant {DNSSEC}},
  year   = {2026},
  note   = {Institute of Engineering \& Management, Kolkata, India},
  url    = {https://github.com/<your-username>/ABHED-v1}
}
```

## License
Copyright 2026 Rajdeep Das, Institute of Engineering & Management (IEM), Kolkata, India.

ABHED-v1 is licensed under the [Apache License, Version 2.0](LICENSE). You may use, modify and
redistribute it, but **every copy and every derivative work must keep the [`LICENSE`](LICENSE) and
[`NOTICE`](NOTICE) files, the copyright headers in the source files, and the creator's name**, and must
state clearly which files were changed. Copyright remains with the author; the license grants usage
rights only. Citation metadata is in [`CITATION.cff`](CITATION.cff), which GitHub shows as a
"Cite this repository" button.

## Contact
Rajdeep Das — Research Fellow, IEM Kolkata, India
E-Mail: Rajdeep.Das2025@iem.edu.in
