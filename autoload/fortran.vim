python3 << EOF
import vim
import git
import os
import re
import tempfile
from difflib import SequenceMatcher
from lxml import etree

use_fypp = True
debug = False

f90_files = []
fypp_files = []
try:
    repo = git.Repo('.', search_parent_directories=True)
    for file in repo.commit().tree.traverse():
        if os.path.isfile(file.abspath):
            if file.abspath.endswith((".f", ".F", ".f90", ".F90")):
                f90_files.append(file.abspath)
            elif file.abspath.endswith(".fypp"):
                fypp_files.append(file.abspath)
except git.InvalidGitRepositoryError:
    for _, _, files in os.walk(os.getcwd()):
        for file in files:
            if os.path.isfile(file.abspath):
                if file.abspath.endswith((".f", ".F", ".f90", ".F90")):
                    f90_files.append(file.abspath)
                elif file.abspath.endswith(".fypp"):
                    fypp_files.append(file.abspath)

def print_debug(mark, element):
    if debug:
        print("   {}: <{}> '{}' :{}".format(mark, element.tag, element.text, element.sourceline))

def load_tree(filename):
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".f90")
    tmp_f90 = tmp.name
    tmp_xml = tmp.name + ".xml"

    redirect = "/dev/null"
    if debug:
        redirect = tmp.name + ".out"
        print(tmp_f90)
        print(redirect)

    bindir = os.path.dirname(vim.eval("s:basedir")) + "/fortran"
    if use_fypp:
        incdirs = set()
        for file in fypp_files:
            incdirs.add(os.path.dirname(file))
        incdirs = " ".join(["--include={}".format(incdir) for incdir in incdirs])
        os.system("{}/fypp/fypp {} {} {} &> {}".format(bindir, incdirs, filename, tmp_f90, redirect))
    else:
        os.system("cp {} {}", filename, tmp_f90)
    filesize = os.stat(tmp_f90).st_size
    if filesize == 0:
        if debug:
            print("fypp error")
        return None, None

    os.system("LD_LIBRARY_PATH=$LD_LIBRARY_PATH:{}/fxtran {}/fxtran/fxtran -construct-tag -no-include -uppercase {} &> {}".format(bindir, bindir, tmp_f90, redirect))
    if not os.path.isfile(tmp_xml):
        if debug:
            print("fxtran error")
        return None, tmp_f90

    tree = etree.parse(tmp_xml)
    if debug:
        print(tmp_xml)
    else:
        os.unlink(tmp_xml)

    for element in tree.findall('.//*'):
        if '}' in element.tag:
            element.tag = element.tag.split('}')[-1]

    if filesize == os.stat(filename).st_size:
        os.unlink(tmp_f90)
        tmp_f90 = filename
    return tree, tmp_f90

def find_module_file(mod):
    regex_mod = re.compile(r"^[ \t]*module[ \t]+", re.IGNORECASE)
    regex_mod_pattern = re.compile(r"^[ \t]*module[ \t]+\b{}\b".format(mod), re.IGNORECASE)

    for file in f90_files:
        try:
            with open(file, 'r') as fd:
                for line in fd:
                    if regex_mod.match(line):
                        if regex_mod_pattern.match(line):
                            return(file)
                        break
        except Exception as e:
            if debug:
                print(e)
            pass
    return None

def find_declaration(filename, orig_filename, tree, pattern, expect, other_file=False):
    if debug:
        print("{} {}:{}".format(pattern, filename, tree.sourceline))

    result = []

    if "variable" in expect[-1]:
        # other%other%pattern
        decl = tree.find(".//named-E//ct[.='{}']..".format(pattern[-1]))
        if decl is not None:
            prev = decl.getprevious()
            if prev is not None:
                decl = prev.find(".//ct")
                if decl is not None:
                    print_debug(1, decl)
                    result.append((filename, orig_filename, decl.sourceline))
                    result.extend(find_declaration(filename, orig_filename, decl, pattern + [decl.text], expect + ["declaration"]))
                    return result

        # other%pattern
        decl = tree.find(".//named-E//ct[.='{}']......//n".format(pattern[-1]))
        if decl is not None:
            print_debug(2, decl)
            result.append((filename, orig_filename, decl.sourceline))
            result.extend(find_declaration(filename, orig_filename, decl, pattern + [decl.text], expect + ["declaration"]))
            return result

    if "declaration" in expect[-1]:
        # type(other) :: pattern
        decl = tree.find(".//EN-N/N/n[.='{}']..........//derived-T-spec//n".format(pattern[-1]))
        if decl is not None:
            print_debug(3, decl)
            result.append((filename, orig_filename, decl.sourceline))
            result.extend(find_declaration(filename, orig_filename, decl, pattern + [decl.text], expect + ["type"]))
            return result

        # integer :: pattern
        decl = tree.find(".//EN-N/N/n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(4, decl)
            result.append((filename, orig_filename, decl.sourceline))
            return result

        # procedure :: pattern => other
        decl = tree.find(".//procedure-stmt//use-N/n[.='{}']..../N/n".format(pattern[-1]))
        if decl is not None:
            print_debug(5, decl)
            result.append((filename, orig_filename, decl.sourceline))
            result.extend(find_declaration(filename, orig_filename, decl, pattern[:-1] + [decl.text], expect[:-1] + ["callable"]))
            return result

        # procedure :: pattern
        decl = tree.find(".//procedure-stmt//use-N/n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(6, decl)
            result.append((filename, orig_filename, decl.sourceline))
            result.extend(find_declaration(filename, orig_filename, decl, pattern, expect[:-1] + ["callable"]))
            return result

        # generic :: pattern => other
        decl = tree.find(".//generic-stmt//n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(7, decl)
            result.append((filename, orig_filename, decl.sourceline))
            result.extend(find_declaration(filename, orig_filename, decl, pattern[:-1] + [decl.text], expect[:-1] + ["callable"]))
            return result

    if "type" in expect[-1]:
        # type pattern
        decl = tree.find(".//T-construct/T-stmt//n[.='{}']........".format(pattern[-1]))
        if decl is not None:
            print_debug(8, decl)
            result.append((filename, orig_filename, decl.sourceline))
            if len(pattern) > 2:
                result.extend(find_declaration(filename, orig_filename, decl, pattern[:-2], expect[:-2]))
            return result

    if "callable" in expect[-1]:
        # interface pattern
        decl = tree.find(".//interface-stmt//n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(9, decl)
            result.append((filename, orig_filename, decl.sourceline))
            return result

        # subroutine pattern
        decl = tree.find(".//subroutine-stmt//n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(10, decl)
            result.append((filename, orig_filename, decl.sourceline))
            return result

        # function pattern
        decl = tree.find(".//function-stmt//n[.='{}']".format(pattern[-1]))
        if decl is not None:
            print_debug(11, decl)
            result.append((filename, orig_filename, decl.sourceline))
            return result

    # use pattern
    decl = tree.find(".//use-stmt/module-N//n[.='{}']".format(pattern[-1]))
    if decl is not None:
        print_debug(12, decl)
        result.append((filename, orig_filename, decl.sourceline))
        orig_mod_filename = find_module_file(decl.text)
        if orig_mod_filename is not None:
            result.append((orig_mod_filename, orig_mod_filename, 1))
        return result

    # use other, only: pattern
    decl = tree.find(".//use-stmt//n[.='{}']........../module-N//n".format(pattern[-1]))
    if decl is not None:
        print_debug(13, decl)
        result.append((filename, orig_filename, decl.sourceline))
        orig_mod_filename = find_module_file(decl.text)
        if orig_mod_filename is not None:
            mod_tree, mod_filename = load_tree(orig_mod_filename)
            if mod_tree is not None:
                result.extend(find_declaration(mod_filename, orig_mod_filename, mod_tree.getroot(), pattern, expect, True))
        return result

    # use other
    if not other_file:
        for decl in tree.findall(".//use-stmt"):
            if decl.find(".//rename-LT") is None:
                mod = decl.find(".//n")
                print_debug(14, mod)
                orig_mod_filename = find_module_file(mod.text)
                if orig_mod_filename is not None:
                    mod_tree, mod_filename = load_tree(orig_mod_filename)
                    if mod_tree is not None:
                        mod = find_declaration(mod_filename, orig_mod_filename, mod_tree.getroot(), pattern, expect, True)
                        if len(mod) > 0:
                            result.append((filename, orig_filename, decl.sourceline))
                            result.extend(mod)
                            return result

    # go to parent program unit and try again
    if tree is not None:
        tree = tree.getparent()
        while tree is not None:
            if tree.tag == "program-unit":
                r = find_declaration(filename, orig_filename, tree, pattern, expect)
                if len(r) > 0:
                    return r
            tree = tree.getparent()

    return []

def find_line_in_file(line, filename):
    matcher = SequenceMatcher()
    matcher.set_seq2(line)
    ratio = 0
    line_number = 0
    with open(filename, 'r') as fd:
        for n, l in enumerate(fd):
            matcher.set_seq1(l)
            r = matcher.ratio()
            if r > ratio:
                ratio = r
                line_number = n + 1
    return line_number

def find(filename, line_number, pattern):
    orig_filename = filename
    tree, filename = load_tree(filename)
    if tree is None:
        return None

    if filename != orig_filename:
        line_number = find_line_in_file(vim.current.line, filename)

    element = None
    for element in tree.findall(".//*[.='{}']".format(pattern.upper())):
        if element.sourceline == line_number:
            break
    if element is None:
        return None

    result = find_declaration(filename, orig_filename, element, [pattern], ["variable_declaration_type_callable"])
    if len(result) == 0:
        return None
    file, orig_file, line = result[-1]

    if file != orig_file:
        with open(file, 'r') as fd:
            line = find_line_in_file(fd.readlines()[line-1], orig_file)

    if file == orig_filename:
        if line is not None:
            return ":{}".format(line)
    else:
        if line is not None:
            return ":edit +{} {}".format(line, orig_file)
        else:
            return ":edit {}".format(orig_file)
    return None

def run():
    filename = vim.eval("l:filename")
    if not filename.endswith((".f", ".F", ".f90", ".F90")):
        print("Not a Fortran file")
        return

    pattern = vim.eval("l:pattern").strip()

    if len(pattern) == 0:
        pattern = vim.eval("@/")
        if pattern.startswith("\<"):
            pattern = pattern[2:]
        if pattern.endswith("\>"):
            pattern = pattern[:-2]

    if len(pattern) == 0:
        print("Empty search query")
        return

    vim.command(":mark Z")

    try:
        command = find(filename, int(vim.eval("line('.')")), pattern.upper())
    except Exception as e:
        print("Error in Fortran plugin: " + str(e))
        if debug:
            raise e
        return
    if command is not None:
        try:
            vim.command(command)
        except vim.error as e:
            print("Error in Fortran plugin: " + str(e))
            return
        print("Go back with `Z")
        return

    print("{} not found".format(pattern))
EOF

let s:basedir = resolve(expand('<sfile>:p'))
function! fortran#Fortran()
    let l:filename = resolve(expand('%:p'))
    let l:pattern = expand('<cword>')
    python3 run()
endfunction
