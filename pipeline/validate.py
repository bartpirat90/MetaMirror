from pipeline.specs import STAT_KEYS


def validate(data, min_sample=15):
    """Gibt eine Liste von Fehlermeldungen zurueck. Leer = gruen."""
    errors = []
    for class_id, specs in data.items():
        for spec_id, contents in specs.items():
            for content, agg in contents.items():
                tag = f"[{class_id}/{spec_id}/{content}]"
                if agg.sample_size < min_sample:
                    errors.append(f"{tag} sampleSize {agg.sample_size} < {min_sample}")
                keys = {s["key"] for s in agg.stats}
                if keys != set(STAT_KEYS):
                    errors.append(f"{tag} stats keys unvollstaendig: {sorted(keys)}")
                for s in agg.stats:
                    if not (0.0 <= s["pct"] <= 100.0):
                        errors.append(f"{tag} pct ausserhalb 0..100: {s['key']}={s['pct']}")
                if not agg.gear:
                    errors.append(f"{tag} gear leer")
                for g in agg.gear:
                    if not g.get("itemID"):
                        errors.append(f"{tag} gear itemID = 0 in {g.get('slot')}")
    return errors
