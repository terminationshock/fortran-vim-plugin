python3 << EOF
import vim
import git
import json
import os
import subprocess
from io import StringIO


def build_request(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, separators=(",", ":"))
    content_length = len(body)
    return "Content-Length: {}\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n\r\n{}".format(content_length, body)


def send_request(path, exclude, method, filename, row, col):
    request = build_request("initialize", {"rootPath": path})
    request += build_request("textDocument/" + method, {"textDocument": {"uri": filename}, "position": {"line": row, "character": col}})

    pid = subprocess.Popen(
        ["fortls", "--incremental_sync", "--disable_autoupdate", "--excl_paths"] + exclude,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    response = pid.communicate(input=request.encode())

    if response is None or len(response) == 0:
        raise Exception("Empty response from fortls")

    lastline = None
    for line in StringIO(response[0].decode()):
        if line.startswith("{"):
            lastline = line

    if lastline is None:
        raise Exception("Invalid response from fortls")

    result = json.loads(lastline)["result"]
    if result is None:
        return None
    if isinstance(result, list):
        return result
    return [result]


def extract_position(response):
    if not "uri" in response or not "range" in response:
        raise Exception("Unsupported response from fortls")

    filename = response["uri"]
    if filename.startswith("file://"):
        filename = filename[7:]

    row = response["range"]["start"]["line"] + 1
    col = response["range"]["start"]["character"] + 1
    return filename, row, col


def evaluate_response(filename, responses):
    if len(responses) == 1:
        new_filename, row, col = extract_position(responses[0])
        if new_filename != filename:
            vim.command(":edit {}".format(new_filename))
        vim.command(":call cursor({}, {})".format(row, col))
    else:
        items = []
        for response in responses:
            file, row, col = extract_position(response)
            items.append("{}:{}:{}".format(file, row, col))

        vim.command(":set efm=%f:%l:%c")
        vim.command(":cexpr [{}]".format(",".join(["'{}'".format(item) for item in items])))
        vim.command(":copen")
        vim.command(":call setqflist([], 'a', {'title' : 'References'})")
        vim.command(":cfirst")


def run(method):
    vim.command(":echon 'Please wait...'")
    vim.command(":redraw")
    filename = vim.eval("l:filename")
    row = int(vim.eval("line('.')")) - 1
    col = int(vim.eval("col('.')")) - 1

    try:
        repo = git.Repo('.', search_parent_directories=True)
        path = repo.working_dir

        exclude = []
        for folder in os.listdir(os.getcwd()):
            if os.path.isdir(folder):
                abspath = os.path.join(path, folder)
                try:
                    repo.git.ls_files(abspath, error_unmatch=True)
                except git.GitCommandError:
                    exclude.append(abspath)
    except git.InvalidGitRepositoryError:
        path = os.getcwd()

    try:
        response = send_request(path, exclude, method, filename, row, col)
        if response is not None:
            vim.command(":echon ''")
            evaluate_response(filename, response)
        else:
            vim.command(":echon 'No result'")
    except Exception as e:
        vim.command(":echon 'Error in Fortran plugin. {}'".format(e))
EOF

function! fortran#FindDefinition()
    let l:filename = resolve(expand('%:p'))
    python3 run("definition")
endfunction

function! fortran#FindReferences()
    let l:filename = resolve(expand('%:p'))
    python3 run("references")
endfunction
