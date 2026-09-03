# -*- coding: utf-8 -*-
import pytest

from pipeline.bump_version import bump_toc, next_version

TOC = (
    "## Interface: 120100\r\n"
    "## Title: MetaMirror\r\n"
    "## Version: 0.9.0\r\n"
    "## Notes: Test\r\n"
    "\r\n"
    "Localization.lua\r\n"
)


def _write(tmp_path, text):
    p = tmp_path / "MetaMirror.toc"
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return str(p)


def test_next_version_increments_patch():
    assert next_version("0.9.0") == "0.9.1"
    assert next_version("0.9.9") == "0.9.10"      # kein Uebertrag auf Minor
    assert next_version("1.0.0") == "1.0.1"


def test_next_version_pads_two_part_version():
    assert next_version("0.9") == "0.9.1"


def test_next_version_rejects_non_numeric():
    with pytest.raises(ValueError):
        next_version("0.9a")


def test_bump_toc_writes_only_the_version_line(tmp_path):
    path = _write(tmp_path, TOC)
    old, new = bump_toc(path)
    assert (old, new) == ("0.9.0", "0.9.1")

    with open(path, encoding="utf-8", newline="") as f:
        result = f.read()
    assert result == TOC.replace("## Version: 0.9.0", "## Version: 0.9.1")
    assert "\r\n" in result                        # Zeilenenden unveraendert


def test_bump_toc_dry_run_leaves_file_untouched(tmp_path):
    path = _write(tmp_path, TOC)
    old, new = bump_toc(path, dry_run=True)
    assert (old, new) == ("0.9.0", "0.9.1")
    with open(path, encoding="utf-8", newline="") as f:
        assert f.read() == TOC


def test_bump_toc_without_version_line_raises(tmp_path):
    path = _write(tmp_path, "## Interface: 120100\r\nLocalization.lua\r\n")
    with pytest.raises(ValueError):
        bump_toc(path)


def test_bump_toc_is_repeatable(tmp_path):
    path = _write(tmp_path, TOC)
    bump_toc(path)
    assert bump_toc(path) == ("0.9.1", "0.9.2")
