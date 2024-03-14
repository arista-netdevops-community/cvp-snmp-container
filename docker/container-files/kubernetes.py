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


def count_string_in_cmd_output_and_add_at_position(position_in_tree, commands, string_to_count):
    """
    count_string_in_cmd_output_and_add_at_position Execute the command and count the number of times the string_to_count is present in the output and add it to the tree.
    Parameters
    ----------
    position_in_tree : str
        Position in the tree to add the data (Ex: '0.' for the first level of the tree)
    commands : list
        The command to call as a list (Ex: ['kubectl', 'get', 'nodes', '-o', 'wide']).
    string_to_count : str
        The string to count in the output of the command
    Returns
    -------
    None
    """
    info_from_subprocess = call_command(commands)
    # logging.debug(f"Info from subprocess: {info_from_subprocess}")
    count = info_from_subprocess.count(string_to_count)
    # logging.debug(f"Count: {count}")
    position = position_in_tree[:-1] # Remove the last dot in position string
    pp.add_int(position, count)


def add_command_in_tree_at_position(position_in_tree, commands):
    """
    add_command_in_tree_at_position Execute the command and add it to the pass persist object at position_in_tree.
    Parameters
    ----------
    position_in_tree : str
        Position in the tree to add the data (Ex: '0.' for the first level of the tree)
    commands : list
        The command to call as a list (Ex: ['kubectl', 'get', 'nodes', '-o', 'wide']).
    Returns
    -------
    None
    """
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

    count_string_in_cmd_output_and_add_at_position("0.", ["kubectl", "get", "pods", "--all-namespaces", "--field-selector=status.phase=Running"], "Running")
    count_string_in_cmd_output_and_add_at_position("1.", ["kubectl", "get", "nodes"], "Ready")
    
    add_command_in_tree_at_position("2.", ["kubectl", "get", "nodes", "-o", "wide"])
    add_command_in_tree_at_position("3.", ["kubectl", "get", "pods", "-o", "wide", "--all-namespaces"])
    # except Exception as e:
    #     logging.error(f"Error: {e}")

pp=snmp.PassPersist(TREE_POSITION_START)
pp.start(update, UPDATE_INTERVAL)