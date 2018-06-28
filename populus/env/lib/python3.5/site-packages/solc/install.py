"""
Install solc
"""
import functools
import os
import stat
import subprocess
import sys
import contextlib

import zipfile


V0_4_1 = 'v0.4.1'
V0_4_2 = 'v0.4.2'
V0_4_6 = 'v0.4.6'
V0_4_7 = 'v0.4.7'
V0_4_8 = 'v0.4.8'
V0_4_9 = 'v0.4.9'
V0_4_11 = 'v0.4.11'
V0_4_12 = 'v0.4.12'
V0_4_13 = 'v0.4.13'
V0_4_14 = 'v0.4.14'
V0_4_15 = 'v0.4.15'
V0_4_16 = 'v0.4.16'
V0_4_17 = 'v0.4.17'
V0_4_18 = 'v0.4.18'
V0_4_19 = 'v0.4.19'


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


SOLIDITY_GIT_URI = "https://github.com/ethereum/solidity.git"


def is_git_repository(path):
    git_dir = os.path.join(
        path,
        '.git',
    )
    return os.path.exists(git_dir)


#
#  Installation filesystem path utilities
#
def get_base_install_path(identifier):
    if 'SOLC_BASE_INSTALL_PATH' in os.environ:
        return os.path.join(
            os.environ['SOLC_BASE_INSTALL_PATH'],
            'solc-{0}'.format(identifier),
        )
    else:
        return os.path.expanduser(os.path.join(
            '~',
            '.py-solc',
            'solc-{0}'.format(identifier),
        ))


def get_repository_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'source',
    )


def get_release_zipfile_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'release.zip',
    )


def get_extract_path(identifier):
    return os.path.join(
        get_base_install_path(identifier),
        'bin',
    )


def get_executable_path(identifier):
    extract_path = get_extract_path(identifier)
    return os.path.join(
        extract_path,
        'solc',
    )


def get_build_dir(identifier):
    repository_path = get_repository_path(identifier)
    return os.path.join(
        repository_path,
        'build',
    )


def get_built_executable_path(identifier):
    build_dir = get_build_dir(identifier)
    return os.path.join(
        build_dir,
        'solc',
        'solc',
    )


#
# Installation primitives.
#
def clone_solidity_repository(identifier):
    if not is_executable_available('git'):
        raise OSError("The `git` is required but was not found")

    repository_path = get_repository_path(identifier)
    ensure_parent_dir_exists(repository_path)
    command = [
        "git", "clone",
        "--recurse-submodules",
        "--branch", identifier,
        "--depth", "10",
        SOLIDITY_GIT_URI,
        repository_path,
    ]

    return check_subprocess_call(
        command,
        message="Checking out solidity repository @ {0}".format(identifier),
    )


def initialize_repository_submodules(identifier):
    if not is_executable_available('git'):
        raise OSError("The `git` is required but was not found")

    repository_path = get_repository_path(identifier)
    command = [
        "git", "submodule", "update", "--init", "--recursive",
    ]
    check_subprocess_call(
        command,
        "Initializing repository submodules @ {0}".format(repository_path),
    )


DOWNLOAD_UBUNTU_RELEASE_URI_TEMPLATE = "https://github.com/ethereum/solidity/releases/download/{0}/solidity-ubuntu-trusty.zip"  # noqa: E501


def download_ubuntu_release(identifier):
    download_uri = DOWNLOAD_UBUNTU_RELEASE_URI_TEMPLATE.format(identifier)
    release_zipfile_path = get_release_zipfile_path(identifier)

    ensure_parent_dir_exists(release_zipfile_path)

    command = [
        "wget", download_uri,
        '-c',  # resume previously incomplete download.
        '-O', release_zipfile_path,
    ]

    return check_subprocess_call(
        command,
        message="Downloading ubuntu release from {0}".format(download_uri),
    )


DOWNLOAD_STATIC_RELEASE_URI_TEMPLATE = "https://github.com/ethereum/solidity/releases/download/{0}/solc-static-linux"  # noqa: E501


def download_static_release(identifier):
    download_uri = DOWNLOAD_STATIC_RELEASE_URI_TEMPLATE.format(identifier)
    static_binary_path = get_executable_path(identifier)

    ensure_parent_dir_exists(static_binary_path)

    command = [
        "wget", download_uri,
        '-c',  # resume previously incomplete download.
        '-O', static_binary_path,
    ]

    return check_subprocess_call(
        command,
        message="Downloading static linux binary from {0}".format(download_uri),
    )


def extract_release(identifier):
    release_zipfile_path = get_release_zipfile_path(identifier)

    extract_path = get_extract_path(identifier)
    ensure_path_exists(extract_path)

    print("Extracting zipfile: {0} -> {1}".format(release_zipfile_path, extract_path))

    with zipfile.ZipFile(release_zipfile_path) as zipfile_file:
        zipfile_file.extractall(extract_path)

    executable_path = get_executable_path(identifier)

    print("Making `solc` binary executable: `chmod +x {0}`".format(executable_path))
    chmod_plus_x(executable_path)


def install_solc_dependencies(identifier):
    repository_path = get_repository_path(identifier)
    if not is_git_repository(repository_path):
        raise OSError("Git repository not found @ {0}".format(repository_path))

    with chdir(repository_path):
        install_deps_script_path = os.path.join(repository_path, 'scripts', 'install_deps.sh')

        return check_subprocess_call(
            command=["sh", install_deps_script_path],
            message="Running dependency installation script `install_deps.sh` @ {0}".format(
                install_deps_script_path,
            ),
        )


def install_solc_from_ubuntu_release_zip(identifier):
    download_ubuntu_release(identifier)
    extract_release(identifier)

    extract_path = get_extract_path(identifier)
    executable_path = get_executable_path(identifier)
    assert os.path.exists(executable_path), "Executable not found @".format(executable_path)

    check_version_command = [executable_path, '--version']

    check_subprocess_output(
        check_version_command,
        message="Checking installed executable version @ {0}".format(executable_path),
        env={'LD_LIBRARY_PATH': extract_path},
    )

    print("solc successfully installed at: {0}".format(executable_path))


def install_solc_from_static_linux(identifier):
    download_static_release(identifier)

    executable_path = get_executable_path(identifier)
    chmod_plus_x(executable_path)

    check_version_command = [executable_path, '--version']

    check_subprocess_output(
        check_version_command,
        message="Checking installed executable version @ {0}".format(executable_path),
    )

    print("solc successfully installed at: {0}".format(executable_path))


def build_solc_from_source(identifier):
    if not is_git_repository(get_repository_path(identifier)):
        clone_solidity_repository(identifier)

    build_dir = get_build_dir(identifier)
    ensure_path_exists(build_dir)

    with chdir(build_dir):
        cmake_command = ["cmake", ".."]
        check_subprocess_call(
            cmake_command,
            message="Running cmake build command",
        )
        make_command = ["make"]
        check_subprocess_call(
            make_command,
            message="Running make command",
        )

    built_executable_path = get_built_executable_path(identifier)
    chmod_plus_x(built_executable_path)

    executable_path = get_executable_path(identifier)
    ensure_parent_dir_exists(executable_path)
    os.symlink(built_executable_path, executable_path)
    chmod_plus_x(executable_path)


def install_from_ubuntu_release(identifier):
    if not is_git_repository(get_repository_path(identifier)):
        clone_solidity_repository(identifier)
    install_solc_dependencies(identifier)
    install_solc_from_ubuntu_release_zip(identifier)

    executable_path = get_executable_path(identifier)
    print("Succesfully installed solc @ `{0}`".format(executable_path))


install_v0_4_1_linux = functools.partial(install_from_ubuntu_release, V0_4_1)
install_v0_4_2_linux = functools.partial(install_from_ubuntu_release, V0_4_2)
install_v0_4_6_linux = functools.partial(install_from_ubuntu_release, V0_4_6)
install_v0_4_7_linux = functools.partial(install_from_ubuntu_release, V0_4_7)
install_v0_4_8_linux = functools.partial(install_from_ubuntu_release, V0_4_8)
install_v0_4_9_linux = functools.partial(install_from_ubuntu_release, V0_4_9)


def install_from_static_linux(identifier):
    install_solc_from_static_linux(identifier)

    executable_path = get_executable_path(identifier)
    print("Succesfully installed solc @ `{0}`".format(executable_path))


install_v0_4_11_linux = functools.partial(install_solc_from_static_linux, V0_4_11)
install_v0_4_12_linux = functools.partial(install_solc_from_static_linux, V0_4_12)
install_v0_4_13_linux = functools.partial(install_solc_from_static_linux, V0_4_13)
install_v0_4_14_linux = functools.partial(install_solc_from_static_linux, V0_4_14)
install_v0_4_15_linux = functools.partial(install_solc_from_static_linux, V0_4_15)
install_v0_4_16_linux = functools.partial(install_solc_from_static_linux, V0_4_16)
install_v0_4_17_linux = functools.partial(install_solc_from_static_linux, V0_4_17)
install_v0_4_18_linux = functools.partial(install_solc_from_static_linux, V0_4_18)
install_v0_4_19_linux = functools.partial(install_solc_from_static_linux, V0_4_19)


def install_from_source(identifier):
    if not is_git_repository(get_repository_path(identifier)):
        clone_solidity_repository(identifier)
    install_solc_dependencies(identifier)
    build_solc_from_source(identifier)

    executable_path = get_executable_path(identifier)
    print("Succesfully installed solc @ `{0}`".format(executable_path))


install_v0_4_8_osx = functools.partial(install_from_source, V0_4_8)
install_v0_4_11_osx = functools.partial(install_from_source, V0_4_11)
install_v0_4_12_osx = functools.partial(install_from_source, V0_4_12)
install_v0_4_13_osx = functools.partial(install_from_source, V0_4_13)
install_v0_4_14_osx = functools.partial(install_from_source, V0_4_14)
install_v0_4_15_osx = functools.partial(install_from_source, V0_4_15)
install_v0_4_16_osx = functools.partial(install_from_source, V0_4_16)
install_v0_4_17_osx = functools.partial(install_from_source, V0_4_17)
install_v0_4_18_osx = functools.partial(install_from_source, V0_4_18)
install_v0_4_19_osx = functools.partial(install_from_source, V0_4_19)


INSTALL_FUNCTIONS = {
    LINUX: {
        V0_4_1: install_v0_4_1_linux,
        V0_4_2: install_v0_4_2_linux,
        V0_4_6: install_v0_4_6_linux,
        V0_4_7: install_v0_4_7_linux,
        V0_4_8: install_v0_4_8_linux,
        V0_4_9: install_v0_4_9_linux,
        V0_4_11: install_v0_4_11_linux,
        V0_4_12: install_v0_4_12_linux,
        V0_4_13: install_v0_4_13_linux,
        V0_4_14: install_v0_4_14_linux,
        V0_4_15: install_v0_4_15_linux,
        V0_4_16: install_v0_4_16_linux,
        V0_4_17: install_v0_4_17_linux,
        V0_4_18: install_v0_4_18_linux,
        V0_4_19: install_v0_4_19_linux,
    },
    OSX: {
        V0_4_8: install_v0_4_8_osx,
        V0_4_11: install_v0_4_11_osx,
        V0_4_12: install_v0_4_12_osx,
        V0_4_13: install_v0_4_13_osx,
        V0_4_14: install_v0_4_14_osx,
        V0_4_15: install_v0_4_15_osx,
        V0_4_16: install_v0_4_16_osx,
        V0_4_17: install_v0_4_17_osx,
        V0_4_18: install_v0_4_18_osx,
        V0_4_19: install_v0_4_19_osx,
    }
}


def install_solc(identifier, platform=None):
    if platform is None:
        platform = get_platform()

    if platform not in INSTALL_FUNCTIONS:
        raise ValueError(
            "Installation of solidity is not supported on your platform ({0}). "
            "Supported platforms are: {1}".format(
                platform,
                ', '.join(sorted(INSTALL_FUNCTIONS.keys())),
            )
        )
    elif identifier not in INSTALL_FUNCTIONS[platform]:
        raise ValueError(
            "Installation of solidity=={0} is not supported.  Must be one of {1}".format(
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
        print("Invocation error.  Should be invoked as `./install_solc.py <release-tag>`")
        sys.exit(1)

    install_solc(identifier)
