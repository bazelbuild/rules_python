import tarfile
import zipfile


class Package:
    def __init__(self, filename, filename_hint=None):
        self.archive = None
        self.filename = filename
        self.filename_hint = filename_hint

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, type, value, tb):
        self.close()

    def open(self):
        if self.archive:
            raise Exception("package already open")

        hint = self.filename_hint or self.filename

        if hint.endswith('.zip') or hint.endswith('.whl'):
            self.archive = zipfile.ZipFile(self.filename)
        else:
            self.archive = tarfile.open(self.filename)

    def close(self):
        if self.archive:
            self.archive.close()
            self.archive = None

    def _ensure_open(self):
        ar = self.archive

        if ar == None:
            raise Exception("archive is not open")

        return ar

    def names(self):
        ar = self._ensure_open()

        if isinstance(ar, zipfile.ZipFile):
            return ar.namelist()
        elif isinstance(ar, tarfile.TarFile):
            return ar.getnames()
        else:
            raise Exception("invalid archive type")

    def read(self, name, encoding='utf-8', loader=None):
        ar = self._ensure_open()

        if isinstance(ar, zipfile.ZipFile):
            data = ar.read(name)
        elif isinstance(ar, tarfile.TarFile):
            data = ar.extractfile(name).read()
        else:
            raise Exception("invalid archive type")

        if encoding != None:
            data = data.decode(encoding)

        if loader != None:
            try:
                data = loader.parse(data)
            except Exception as e:
                print('Error loading %s: ' % name, e)

                return None

        return data

    def read_if_exists(self, file, default=None, **kwargs):
        if file not in self.names():
            return default

        return self.read(file, **kwargs)
