#!/usr/bin/env python3
"""Produce an NDJSON file to a Kafka topic using the broker's own CLI."""

import sys

import _common


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("file", help="NDJSON file, one record per line")
    p.add_argument("-t", "--topic", help="target topic (default: the ingest topic)")
    p.add_argument("-w", "--workers", type=int, help="concurrent producers")
    p.add_argument("-r", "--rate", type=int, help="events/sec, 0 = unthrottled")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    cfg = ctx.cfg

    topic = args.topic or cfg["kafka"]["ingest_topic"]
    before = ctx.kafka.total_end_offset(topic)
    res = ctx.kafka.produce_file(
        topic, args.file,
        workers=args.workers or cfg["load"]["concurrent_producers"],
        rate=args.rate if args.rate is not None else cfg["load"]["producer_rate"],
        batch_size=cfg["load"]["batch_size"])
    res["end_offset_delta"] = ctx.kafka.total_end_offset(topic) - before
    _common.dump(res)
    return 0


if __name__ == "__main__":
    sys.exit(main())
