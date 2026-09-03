import io
import zipfile

from pipeline import cf_upload as cf


def test_iface_to_version():
    assert cf.iface_to_version("120100") == "12.1.0"
    assert cf.iface_to_version("110205") == "11.2.5"
    assert cf.iface_to_version("120000") == "12.0.0"


def test_parse_toc_reads_version_and_files():
    version, interface, files = cf.parse_toc(cf.TOC)
    assert version and interface
    assert "UI.lua" in files
    assert all("\\" not in f for f in files)   # Backslashes normalisiert


def test_build_zip_is_clean_and_complete():
    version, interface, data = cf.build_zip()
    names = zipfile.ZipFile(io.BytesIO(data)).namelist()
    # Top-Level-Ordner + Pflichtdateien
    assert "MetaMirror/MetaMirror.toc" in names
    assert "MetaMirror/UI.lua" in names
    assert "MetaMirror/Icon.tga" in names
    assert "MetaMirror/bar-mask.tga" in names
    # niemals Sensibles/Fremdes einpacken
    joined = "\n".join(names).lower()
    for bad in ("secret", "pipeline/", "talents", ".git", "release/"):
        assert bad not in joined
