#!/usr/bin/python3 -u

import snmp_passpersist as snmp

import subprocess

# Enable logging to a file for debugging purposes
# import logging
# logging.basicConfig(filename='/script_snmp.log', encoding='utf-8', level=logging.DEBUG)
# logging.debug('Init logging for script_snmp.py')

# The position in the tree where the data will be added - SNMPv2-SMI::experimental network-objects
TREE_POSITION_START = ".1.3.6.1.3.53.8"

UPDATE_INTERVAL = 60 # Interval in seconds at which the script will be called


def call_command(command):
    """
    call_command Execute the command as a subprocess and return the output decoded in ascii.
    Parameters
    ----------
    command : list
        The command to call as a list (Ex: ['kubectl', 'get', 'nodes', '-o', 'wide'])
    Returns
    -------
    str
        The output of the command decoded in ascii
    """
    # logging.debug(f"Calling command: '{command}'")
    output = subprocess.check_output(command, stderr=subprocess.DEVNULL)
    return output.decode("ascii")

def call_command_with_pipe(command1, command2):
    """
    call_command_with_pipe Execute the commands in a subprocess as `command1 | command2`. Return the output decoded in ascii.
    Parameters
    ----------
    command1 : list
        The command to call as a list (Ex: ['kubectl', 'get', 'nodes', '-o', 'wide'])
    command2 : list
        The command to call as a list (Ex: ['wc',  '-l'])
    Returns
    -------
    str
        The output of the command decoded in ascii
    """
    # logging.debug(f"Calling commands with pipe: {command1} - {command2}")
    ps = subprocess.Popen(command1, stdout=subprocess.PIPE)
    output = subprocess.check_output(command2, stdin=ps.stdout)
    ps.wait()
    return output.decode("ascii")

def add_command_in_tree_at_position(position_in_tree, commands, has_pipe=False, is_int=False):
    """
    add_command_in_tree_at_position Execute the command and add it to the pass persist object at position_in_tree.
    Parameters
    ----------
    position_in_tree : str
        Position in the tree to add the data (Ex: '0.' for the first level of the tree)
    commands : list
        The command to call as a list (Ex: ['kubectl', 'get', 'nodes', '-o', 'wide']).
        If has_pipe is True, expected a list of two commands (Ex: [['kubectl', 'get', 'pods'], ['wc',  '-l']])
    has_pipe : bool, optional
        If True, the commands will be executed with a pipe (default is False).
    Returns
    -------
    None
    """
    if has_pipe:
        info_from_subprocess = call_command_with_pipe(commands[0], commands[1])
        position = position_in_tree[:-1] # Removing the last dot from the position string.
        # logging.debug(f"Adding value at [{position}] : '{info_from_subprocess}'")
        if is_int:
            pp.add_int(position, int(info_from_subprocess))
        else:
            pp.add_str(position, info_from_subprocess)

    else:
        info_from_subprocess = call_command(commands)
        # Split the string into lines
        lines = info_from_subprocess.strip().split('\n')
        # logging.debug(f"Lines: {lines}")
        
        # Process each line (excluding the first line of headers)
        for index_line, line in enumerate(lines[1:]):
            position = position_in_tree + str(index_line)
            pp.add_str(position, line)

def update():
    # try:
    add_command_in_tree_at_position("0.", [["kubectl", "get", "pods", "--all-namespaces", "--field-selector=status.phase=Running"], ["wc",  "-l"]], has_pipe=True, is_int=True)
    add_command_in_tree_at_position("1.", ["kubectl", "get", "nodes", "-o", "wide"])
    add_command_in_tree_at_position("2.", ["kubectl", "get", "pods", "-o", "wide", "--all-namespaces"])
    # except Exception as e:
    #     logging.error(f"Error: {e}")

pp=snmp.PassPersist(TREE_POSITION_START)
pp.start(update, UPDATE_INTERVAL)