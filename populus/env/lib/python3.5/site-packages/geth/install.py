"""
Install geth
"""
import contextlib
import functools
import os
import stat
import subprocess
import sys
import tarfile


V1_5_6 = 'v1.5.6'
V1_5_7 = 'v1.5.7'
V1_5_8 = 'v1.5.8'
V1_5_9 = 'v1.5.9'
V1_6_0 = 'v1.6.0'
V1_6_1 = 'v1.6.1'
V1_6_2 = 'v1.6.2'
V1_6_3 = 'v1.6.3'
V1_6_4 = 'v1.6.4'
V1_6_5 = 'v1.6.5'
V1_6_6 = 'v1.6.6'
V1_6_7 = 'v1.6.7'
V1_7_0 = 'v1.7.0'
V1_7_2 = 'v1.7.2'
V1_8_1 = 'v1.8.1'


LINUX = 'linux'
OSX = 'darwin'
WINDOWS = 'win32'


#
# System utilities.
#
@contextlib.contextmanager
def chdir(path):
    original_path = os.getcwd()
    try:
        os.chdir(path)
        yield
    finally:
        os.chdir(original_path)


def get_platform():
    if sys.platform.startswith('linux'):
        return LINUX
    elif sys.platform == OSX:
        return OSX
    elif sys.platform == WINDOWS:
        return WINDOWS
    else:
        raise KeyError("Unknown platform: {0}".format(sys.platform))


def is_executable_available(program):
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath = os.path.dirname(program)
    if fpath:
        if is_exe(program):
            return True
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return True

    return False


def ensure_path_exists(dir_path):
    """
    Make sure that a path exists
    """
    if not os.path.exists(dir_path):
        os.makedirs(dir_path)
        return True
    return False


def ensure_parent_dir_exists(path):
    ensure_path_exists(os.path.dirname(path))


def check_subprocess_call(command, message=None, stderr=subprocess.STDOUT, **proc_kwargs):
    if message:
        print(message)
    print("Executing: {0}".format(" ".join(command)))

    return subprocess.check_call(
        command,
        stderr=subprocess.STDOUT,
        **proc_kwargs
    )


def check_subprocess_output(command, message=None, stderr=subprocess.STDOUT, **proc_kwargs):
    if message:
        print(message)
    print("Executing: {0}".format(" ".join(command)))

    return subprocess.check_output(
        command,
        stderr=subprocess.STDOUT,
        **proc_kwargs
    )


def chmod_plus_x(executable_path):
    current_st = os.stat(executable_path)
    os.chmod(executable_path, current_st.st_mode | stat.S_IEXEC)


def get_go_executable_path():
    return os.environ.get('GO_BINARY', 'go')


def is_go_available():
    return is_executable_available(get_go_executable_path())


#
#  Installation filesystem path utilities
#
def get_base_install_path(identifier):
    if 'GETH_BASE_INSTALL_PATH' in os.environ:
        return os.path.join(
            os.environ['GETH_BASE_INSTALL_PATH'],
            'geth-{0}'.format(identifier),
        )
    else:
        return os.path.expanduser(os.path.join(
            '~',
            '.py-geth',
            'geth-{0}'.format(identifier),
        ))


def get_source_code_archive_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'release.tar.gz',
    )


def get_source_code_extract_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'source',
    )


def get_source_code_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'source',
        'go-ethereum-{0}'.format(identifier.lstrip('v')),
    )


def get_build_path(identifier):
    source_code_path = get_source_code_path(identifier)
    return os.path.join(
        source_code_path,
        'build',
    )


def get_built_executable_path(identifier):
    build_path = get_build_path(identifier)
    return os.path.join(
        build_path,
        'bin',
        'geth',
    )


def get_executable_path(identifier):
    base_install_path = get_base_install_path(identifier)
    return os.path.join(
        base_install_path,
        'bin',
        'geth',
    )


#
# Installation primitives.
#
DOWNLOAD_SOURCE_CODE_URI_TEMPLATE = "https://github.com/ethereum/go-ethereum/archive/{0}.tar.gz"  # noqa: E501


def download_source_code_release(identifier):
    download_uri = DOWNLOAD_SOURCE_CODE_URI_TEMPLATE.format(identifier)
    source_code_archive_path = get_source_code_archive_path(identifier)

    ensure_parent_dir_exists(source_code_archive_path)

    command = [
        "wget", download_uri,
        '-c',  # resume previously incomplete download.
        '-O', source_code_archive_path,
    ]

    return check_subprocess_call(
        command,
        message="Downloading source code release from {0}".format(download_uri),
    )


def extract_source_code_release(identifier):
    source_code_archive_path = get_source_code_archive_path(identifier)

    source_code_extract_path = get_source_code_extract_path(identifier)
    ensure_path_exists(source_code_extract_path)

    print("Extracting archive: {0} -> {1}".format(
        source_code_archive_path,
        source_code_extract_path,
    ))

    with tarfile.open(source_code_archive_path, 'r:gz') as archive_file:
        archive_file.extractall(source_code_extract_path)


def build_from_source_code(identifier):
    if not is_go_available():
        raise OSError(
            "The `go` runtime was not found but is required to build geth.  If "
            "the `go` executable is not in your $PATH you can specify the path "
            "using the environment variable GO_BINARY to specify the path."
        )
    source_code_path = get_source_code_path(identifier)

    with chdir(source_code_path):
        make_command = ["make", "geth"]

        check_subprocess_call(
            make_command,
            message="Building `geth` binary",
        )

    built_executable_path = get_built_executable_path(identifier)
    if not os.path.exists(built_executable_path):
        raise OSError(
            "Built executable not found in expected location: "
            "{0}".format(built_executable_path)
        )
    print("Making built binary executable: chmod +x {0}".format(built_executable_path))
    chmod_plus_x(built_executable_path)

    executable_path = get_executable_path(identifier)
    ensure_parent_dir_exists(executable_path)
    if os.path.exists(executable_path):
        if os.path.islink(executable_path):
            os.remove(executable_path)
        else:
            raise OSError("Non-symlink file already present at `{0}`".format(executable_path))
    os.symlink(built_executable_path, executable_path)
    chmod_plus_x(executable_path)


def install_from_source_code_release(identifier):
    download_source_code_release(identifier)
    extract_source_code_release(identifier)
    build_from_source_code(identifier)

    executable_path = get_executable_path(identifier)
    assert os.path.exists(executable_path), "Executable not found @".format(executable_path)

    check_version_command = [executable_path, 'version']

    version_output = check_subprocess_output(
        check_version_command,
        message="Checking installed executable version @ {0}".format(executable_path),
    )

    print("geth successfully installed at: {0}\n\n{1}\n\n".format(
        executable_path,
        version_output,
    ))


install_v1_5_6 = functools.partial(install_from_source_code_release, V1_5_6)
install_v1_5_7 = functools.partial(install_from_source_code_release, V1_5_7)
install_v1_5_8 = functools.partial(install_from_source_code_release, V1_5_8)
install_v1_5_9 = functools.partial(install_from_source_code_release, V1_5_9)
install_v1_6_0 = functools.partial(install_from_source_code_release, V1_6_0)
install_v1_6_1 = functools.partial(install_from_source_code_release, V1_6_1)
install_v1_6_2 = functools.partial(install_from_source_code_release, V1_6_2)
install_v1_6_3 = functools.partial(install_from_source_code_release, V1_6_3)
install_v1_6_4 = functools.partial(install_from_source_code_release, V1_6_4)
install_v1_6_5 = functools.partial(install_from_source_code_release, V1_6_5)
install_v1_6_6 = functools.partial(install_from_source_code_release, V1_6_6)
install_v1_6_7 = functools.partial(install_from_source_code_release, V1_6_7)
install_v1_7_0 = functools.partial(install_from_source_code_release, V1_7_0)
install_v1_7_2 = functools.partial(install_from_source_code_release, V1_7_2)
install_v1_8_1 = functools.partial(install_from_source_code_release, V1_8_1)


INSTALL_FUNCTIONS = {
    LINUX: {
        V1_5_6: install_v1_5_6,
        V1_5_7: install_v1_5_7,
        V1_5_8: install_v1_5_8,
        V1_5_9: install_v1_5_9,
        V1_6_0: install_v1_6_0,
        V1_6_1: install_v1_6_1,
        V1_6_2: install_v1_6_2,
        V1_6_3: install_v1_6_3,
        V1_6_4: install_v1_6_4,
        V1_6_5: install_v1_6_5,
        V1_6_6: install_v1_6_6,
        V1_6_7: install_v1_6_7,
        V1_7_0: install_v1_7_0,
        V1_7_2: install_v1_7_2,
        V1_8_1: install_v1_8_1,
    },
    OSX: {
        V1_5_6: install_v1_5_6,
        V1_5_7: install_v1_5_7,
        V1_5_8: install_v1_5_8,
        V1_5_9: install_v1_5_9,
        V1_6_0: install_v1_6_0,
        V1_6_1: install_v1_6_1,
        V1_6_2: install_v1_6_2,
        V1_6_3: install_v1_6_3,
        V1_6_4: install_v1_6_4,
        V1_6_5: install_v1_6_5,
        V1_6_6: install_v1_6_6,
        V1_6_7: install_v1_6_7,
        V1_7_0: install_v1_7_0,
        V1_7_2: install_v1_7_2,
        V1_8_1: install_v1_8_1,
    }
}


def install_geth(identifier, platform=None):
    if platform is None:
        platform = get_platform()

    if platform not in INSTALL_FUNCTIONS:
        raise ValueError(
            "Installation of go-ethereum is not supported on your platform ({0}). "
            "Supported platforms are: {1}".format(
                platform,
                ', '.join(sorted(INSTALL_FUNCTIONS.keys())),
            )
        )
    elif identifier not in INSTALL_FUNCTIONS[platform]:
        raise ValueError(
            "Installation of geth=={0} is not supported.  Must be one of {1}".format(
                identifier,
                ', '.join(sorted(INSTALL_FUNCTIONS[platform].keys())),
            )
        )

    install_fn = INSTALL_FUNCTIONS[platform][identifier]
    install_fn()


if __name__ == "__main__":
    try:
        identifier = sys.argv[1]
    except IndexError:
        print("Invocation error.  Should be invoked as `python -m geth.install <release-tag>`")
        sys.exit(1)

    install_geth(identifier)
