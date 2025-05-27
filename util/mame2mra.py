#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "tomli"
# ]
# ///

"""
MAME to MRA Converter for MiSTer FPGA

This script parses MAME XML data and creates MiSTer MRA files.
It parses XML data into Machine objects and can generate MRA files.
"""

import xml.etree.ElementTree as ET
import os
import argparse
import re
import tomli
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any, Tuple


@dataclass
class ROM:
    """Represents a ROM entry in a MAME machine."""
    name: str
    size: int
    crc: Optional[str] = None
    sha1: Optional[str] = None
    region: Optional[str] = None
    offset: Optional[int] = None
    status: str = "good"
    optional: bool = False
    bios: Optional[str] = None
    merge: Optional[str] = None


@dataclass
class Display:
    """Represents a display entry in a MAME machine."""
    type: str
    rotate: Optional[int] = None
    flipx: bool = False
    width: Optional[int] = None
    height: Optional[int] = None
    refresh: Optional[float] = None
    tag: Optional[str] = None
    pixclock: Optional[int] = None
    htotal: Optional[int] = None
    hbend: Optional[int] = None
    hbstart: Optional[int] = None
    vtotal: Optional[int] = None
    vbend: Optional[int] = None
    vbstart: Optional[int] = None


@dataclass
class DipValue:
    """Represents a dip switch value in a MAME machine."""
    name: str
    value: str
    default: bool = False


@dataclass
class DipSwitch:
    """Represents a dip switch in a MAME machine."""
    name: str
    tag: str
    mask: str
    values: List[DipValue] = field(default_factory=list)


@dataclass
class Machine:
    """Represents a machine/game in MAME."""
    name: str
    description: str
    year: Optional[str] = None
    manufacturer: Optional[str] = None
    sourcefile: Optional[str] = None
    cloneof: Optional[str] = None
    romof: Optional[str] = None
    isbios: bool = False
    isdevice: bool = False
    ismechanical: bool = False
    runnable: bool = True
    roms: List[ROM] = field(default_factory=list)
    displays: List[Display] = field(default_factory=list)
    dipswitches: List[DipSwitch] = field(default_factory=list)


class MAMEParser:
    """Parser for MAME XML files."""

    def __init__(self, xml_file_path):
        self.xml_file_path = xml_file_path
        self.machines = []

    def parse(self):
        """Parse the MAME XML file and create Machine objects."""
        try:
            tree = ET.parse(self.xml_file_path)
            root = tree.getroot()
            
            for machine_elem in root.findall('machine'):
                machine = self._parse_machine(machine_elem)
                self.machines.append(machine)
                
            return self.machines
                
        except ET.ParseError as e:
            print(f"Error parsing XML file: {e}")
            return []
        
    def _parse_machine(self, machine_elem):
        """Parse a machine element and create a Machine object."""
        # Extract machine attributes
        attrs = machine_elem.attrib
        name = attrs.get('name')
        sourcefile = attrs.get('sourcefile')
        cloneof = attrs.get('cloneof')
        romof = attrs.get('romof')
        isbios = attrs.get('isbios') == 'yes'
        isdevice = attrs.get('isdevice') == 'yes'
        ismechanical = attrs.get('ismechanical') == 'yes'
        runnable = attrs.get('runnable', 'yes') == 'yes'
        
        # Extract description, year, and manufacturer
        description = machine_elem.findtext('description', '')
        year = machine_elem.findtext('year')
        manufacturer = machine_elem.findtext('manufacturer')
        
        # Create machine object
        machine = Machine(
            name=name,
            description=description,
            year=year,
            manufacturer=manufacturer,
            sourcefile=sourcefile,
            cloneof=cloneof,
            romof=romof,
            isbios=isbios,
            isdevice=isdevice,
            ismechanical=ismechanical,
            runnable=runnable
        )
        
        # Parse ROMs
        for rom_elem in machine_elem.findall('rom'):
            rom = self._parse_rom(rom_elem)
            machine.roms.append(rom)
            
        # Parse displays
        for display_elem in machine_elem.findall('display'):
            display = self._parse_display(display_elem)
            machine.displays.append(display)
            
        # Parse dipswitches
        for dipswitch_elem in machine_elem.findall('dipswitch'):
            dipswitch = self._parse_dipswitch(dipswitch_elem)
            machine.dipswitches.append(dipswitch)
            
        return machine
        
    def _parse_rom(self, rom_elem):
        """Parse a ROM element and create a ROM object."""
        attrs = rom_elem.attrib
        
        # Required attributes
        name = attrs.get('name')
        size = int(attrs.get('size', 0))
        
        # Optional attributes
        crc = attrs.get('crc')
        sha1 = attrs.get('sha1')
        region = attrs.get('region')
        offset_str = attrs.get('offset')
        
        # Handle offset as hexadecimal or decimal
        offset = None
        if offset_str is not None:
            try:
                # Try parsing as a regular integer (decimal or hex with 0x prefix)
                offset = int(offset_str, 0)
            except ValueError:
                # If that fails, try parsing as a hexadecimal without 0x prefix
                try:
                    offset = int(offset_str, 16)
                except ValueError:
                    print(f"Warning: Could not parse offset '{offset_str}' for ROM '{name}'")
                    
        status = attrs.get('status', 'good')
        optional = attrs.get('optional', 'no') == 'yes'
        bios = attrs.get('bios')
        merge = attrs.get('merge')
        
        return ROM(
            name=name,
            size=size,
            crc=crc,
            sha1=sha1,
            region=region,
            offset=offset,
            status=status,
            optional=optional,
            bios=bios,
            merge=merge
        )
        
    def _parse_display(self, display_elem):
        """Parse a display element and create a Display object."""
        attrs = display_elem.attrib
        
        # Required attributes
        display_type = attrs.get('type')
        
        # Optional attributes
        tag = attrs.get('tag')
        rotate_str = attrs.get('rotate')
        rotate = int(rotate_str) if rotate_str is not None else None
        flipx = attrs.get('flipx', 'no') == 'yes'
        
        width_str = attrs.get('width')
        width = int(width_str) if width_str is not None else None
        
        height_str = attrs.get('height')
        height = int(height_str) if height_str is not None else None
        
        refresh_str = attrs.get('refresh')
        refresh = None
        if refresh_str is not None:
            try:
                refresh = float(refresh_str)
            except ValueError:
                print(f"Warning: Could not parse refresh rate '{refresh_str}' for display")
        
        pixclock_str = attrs.get('pixclock')
        pixclock = int(pixclock_str) if pixclock_str is not None else None
        
        htotal_str = attrs.get('htotal')
        htotal = int(htotal_str) if htotal_str is not None else None
        
        hbend_str = attrs.get('hbend')
        hbend = int(hbend_str) if hbend_str is not None else None
        
        hbstart_str = attrs.get('hbstart')
        hbstart = int(hbstart_str) if hbstart_str is not None else None
        
        vtotal_str = attrs.get('vtotal')
        vtotal = int(vtotal_str) if vtotal_str is not None else None
        
        vbend_str = attrs.get('vbend')
        vbend = int(vbend_str) if vbend_str is not None else None
        
        vbstart_str = attrs.get('vbstart')
        vbstart = int(vbstart_str) if vbstart_str is not None else None
        
        return Display(
            type=display_type,
            tag=tag,
            rotate=rotate,
            flipx=flipx,
            width=width,
            height=height,
            refresh=refresh,
            pixclock=pixclock,
            htotal=htotal,
            hbend=hbend,
            hbstart=hbstart,
            vtotal=vtotal,
            vbend=vbend,
            vbstart=vbstart
        )
        
    def _parse_dipswitch(self, dipswitch_elem):
        """Parse a dipswitch element and create a DipSwitch object."""
        attrs = dipswitch_elem.attrib
        
        name = attrs.get('name')
        tag = attrs.get('tag')
        mask = attrs.get('mask')
        
        dipswitch = DipSwitch(name=name, tag=tag, mask=mask)
        
        # Parse dipvalues
        for dipvalue_elem in dipswitch_elem.findall('dipvalue'):
            dipvalue_attrs = dipvalue_elem.attrib
            dipvalue_name = dipvalue_attrs.get('name')
            dipvalue_value = dipvalue_attrs.get('value')
            dipvalue_default = dipvalue_attrs.get('default', 'no') == 'yes'
            
            dipvalue = DipValue(
                name=dipvalue_name,
                value=dipvalue_value,
                default=dipvalue_default
            )
            
            dipswitch.values.append(dipvalue)
            
        return dipswitch


class MRAGenerator:
    """Generates MRA files from Machine objects for MiSTer FPGA."""
    
    def __init__(self, machine, core_name="TaitoF2", output_dir=".", rbf=None, config_file=None, filename_prefix=""):
        self.machine = machine
        self.core_name = core_name
        self.output_dir = output_dir
        self.rbf = rbf or core_name
        self.config_file = config_file or os.path.join(os.path.dirname(__file__), "mame2mra.toml")
        self.filename_prefix = filename_prefix
        self.region_map = self._load_region_map()
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
    
    def _load_region_map(self):
        """Load the region mapping and machine configs from TOML file."""
        try:
            with open(self.config_file, "rb") as f:
                self.config = tomli.load(f)
                # Extract region mapping with the new format
                regions_data = self.config.get("regions", {})
                region_map = {}
                
                # Process each region entry
                for region_name, value in regions_data.items():
                    # Handle different formats of region specification
                    if isinstance(value, dict):
                        # New format: {id = x, swap = y}
                        region_id = value.get("id")
                        swap = value.get("swap", False)
                        if region_id is not None:
                            region_map[region_name] = {"id": region_id, "swap": swap}
                    elif isinstance(value, int):
                        # Old format still supported: direct ID assignment
                        region_map[region_name] = {"id": value, "swap": False}
                    elif "." in region_name:
                        # Handle cases like "region.id = 1" or "region.swap = true"
                        base_name, attribute = region_name.split(".", 1)
                        
                        # Create entry if it doesn't exist
                        if base_name not in region_map:
                            region_map[base_name] = {"id": None, "swap": False}
                            
                        # Set the attribute
                        if attribute == "id":
                            region_map[base_name]["id"] = value
                        elif attribute == "swap":
                            region_map[base_name]["swap"] = value
                
                return region_map
        except Exception as e:
            print(f"Warning: Could not load region mapping from {self.config_file}: {e}")
            self.config = {}
            return {}
    
    def _apply_abbreviations(self, text):
        """Apply abbreviations from TOML config to text."""
        abbreviations = self.config.get("abbreviations", {})
        return abbreviations.get(text, text)
    
    def _validate_dipswitch_length(self, dipswitch_name, value_names):
        """Validate that dipswitch name and all value names are within 24 character limit."""
        if len(dipswitch_name) > 24:
            print(f"Warning: Dipswitch name '{dipswitch_name}' is {len(dipswitch_name)} characters (max 24)")
        
        for value_name in value_names:
            if len(value_name) > 24:
                print(f"Warning: Dipvalue name '{value_name}' is {len(value_name)} characters (max 24)")
            combined_length = len(dipswitch_name) + len(value_name)
            if combined_length > 24:
                print(f"Warning: Combined length of dipswitch '{dipswitch_name}' + value '{value_name}' is {combined_length} characters (max 24)")
    
    def generate_mra(self):
        """Generate an MRA file for the machine."""
        # Create the MRA XML structure
        mra = ET.Element("misterromdescription")
        
        # Add core metadata
        self._add_child(mra, "name", self.machine.description)
        self._add_child(mra, "setname", self.machine.name)
        if self.machine.year:
            self._add_child(mra, "year", self.machine.year)
        if self.machine.manufacturer:
            self._add_child(mra, "manufacturer", self.machine.manufacturer)
        self._add_child(mra, "rbf", self.rbf)
        
        # Add parent tag if romof is present
        if self.machine.romof:
            self._add_child(mra, "parent", self.machine.romof)
        
        # Add rotation metadata from display info
        for display in self.machine.displays:
            if display.rotate is not None:
                # Convert numeric rotation to descriptive string
                rotation_map = {
                    0: "horizontal",
                    90: "vertical (cw)",
                    270: "vertical (ccw)"
                }
                
                rotation_value = rotation_map.get(display.rotate, str(display.rotate))
                self._add_child(mra, "rotation", rotation_value)
                break
        
        # Add metadata from TOML file
        self._add_metadata(mra)
        
        # Add buttons configuration
        self._add_buttons_configuration(mra)
        
        # Add dipswitches if present
        if self.machine.dipswitches:
            switches = ET.SubElement(mra, "switches")
            
            # Calculate the default value by OR-ing all default values
            default_value = 0
            
            # First pass - calculate default value
            for dipswitch in self.machine.dipswitches:
                try:
                    # Check if the dipswitch tag is valid
                    if dipswitch.tag not in ["DSWA", "DSWB"]:
                        continue
                    
                    # Find the default value for this dipswitch
                    for value in dipswitch.values:
                        if value.default:
                            value_int = int(value.value)
                            # Apply shift for DSWB
                            if dipswitch.tag == "DSWB":
                                value_int <<= 8
                            # OR with the default value
                            default_value |= value_int
                except Exception as e:
                    print(f"Error calculating default for dipswitch '{dipswitch.name}': {e}")
            
            # Set the default attribute as a hex value without 0x prefix
            switches.set("default", f"{default_value:x}")
            
            # Second pass - process each dipswitch
            for dipswitch in self.machine.dipswitches:
                try:
                    # Check if the dipswitch tag is valid
                    if dipswitch.tag not in ["DSWA", "DSWB"]:
                        print(f"Warning: Unknown dipswitch tag '{dipswitch.tag}' for switch '{dipswitch.name}'. Skipping.")
                        continue
                    
                    # Parse mask to determine bits
                    mask_value = int(dipswitch.mask)
                    
                    # Apply shift for DSWB
                    if dipswitch.tag == "DSWB":
                        mask_value <<= 8
                    
                    # Find the lowest and highest set bits
                    if mask_value == 0:
                        print(f"Warning: Zero mask for dipswitch '{dipswitch.name}'. Skipping.")
                        continue
                    
                    # Find lowest and highest bit positions
                    lowest_bit = None
                    highest_bit = None
                    
                    for bit_pos in range(32):  # 32-bit integer
                        if mask_value & (1 << bit_pos):
                            if lowest_bit is None:
                                lowest_bit = bit_pos
                            highest_bit = bit_pos
                    
                    # Create bits attribute - if only one bit, just show that bit
                    # If multiple bits, show "lowest,highest"
                    if lowest_bit == highest_bit:
                        bits_attr = str(lowest_bit)
                    else:
                        bits_attr = f"{lowest_bit},{highest_bit}"
                    
                    # Apply abbreviations to dipswitch and value names
                    abbreviated_dipswitch_name = self._apply_abbreviations(dipswitch.name)
                    
                    # Process value IDs - ensure they match only the relevant bits in the mask
                    values_list = []
                    abbreviated_value_names = []
                    for value in dipswitch.values:
                        value_int = int(value.value) 
                        # If DSWB, shift the value
                        if dipswitch.tag == "DSWB":
                            value_int <<= 8
                        
                        # Apply mask to extract only relevant bits
                        masked_value = value_int & mask_value
                        
                        # Now shift right by lowest_bit to normalize the value
                        normalized_value = masked_value >> lowest_bit
                        
                        values_list.append(str(normalized_value))
                        abbreviated_value_names.append(self._apply_abbreviations(value.name))
                    
                    # Validate length requirements
                    self._validate_dipswitch_length(abbreviated_dipswitch_name, abbreviated_value_names)
                    
                    # Create dipswitch entry
                    dip = ET.SubElement(switches, "dip")
                    dip.set("name", abbreviated_dipswitch_name)
                    dip.set("bits", bits_attr)
                    dip.set("values", ",".join(values_list))
                    dip.set("ids", ",".join(abbreviated_value_names))
                    
                except Exception as e:
                    print(f"Error processing dipswitch '{dipswitch.name}': {e}. Skipping.")
        
        # Add ROMs section
        roms = ET.SubElement(mra, "rom")
        roms.set("index", "0")
        roms.set("address", "0x30000000")
        
        # Set zip attribute, including parent zip if romof is present
        if self.machine.romof:
            roms.set("zip", f"{self.machine.name}.zip|{self.machine.romof}.zip")
        else:
            roms.set("zip", f"{self.machine.name}.zip")
        
        # Group ROMs by region and process each group
        self._process_rom_regions(roms)
        
        # Create the XML string
        mra_string = self._prettify(mra)
        
        # Create a valid filename from the description
        # Replace invalid characters with underscores
        safe_description = self._sanitize_filename(self.machine.description)
        
        # Add prefix to filename if provided
        filename = f"{self.filename_prefix}{safe_description}.mra"
        
        # Write to file
        output_file = os.path.join(self.output_dir, filename)
        with open(output_file, 'w') as f:
            f.write(mra_string)
            
        return output_file
        
    def _sanitize_filename(self, filename):
        """Convert a string to a valid filename."""
        # Replace invalid characters with underscores or other valid characters
        safe_name = filename
        safe_name = safe_name.replace('/', '-')  # Replace slashes with hyphens
        safe_name = safe_name.replace('\\', '-')  # Replace backslashes with hyphens
        safe_name = safe_name.replace(':', '-')   # Replace colons with hyphens
        safe_name = safe_name.replace('*', '_')   # Replace asterisks with underscores
        safe_name = safe_name.replace('?', '_')   # Replace question marks with underscores
        safe_name = safe_name.replace('<', '_')   # Replace less than with underscores
        safe_name = safe_name.replace('>', '_')   # Replace greater than with underscores
        safe_name = safe_name.replace('|', '_')   # Replace pipes with underscores
        safe_name = safe_name.replace('"', '')    # Remove quotes
        
        # Remove leading/trailing spaces and dots
        safe_name = safe_name.strip('. ')
        
        # Ensure the name is not empty
        if not safe_name:
            safe_name = "unnamed"
            
        return safe_name
    
    def _process_rom_regions(self, roms_elem):
        """Process ROM regions and add them to the XML."""
        # First, add machine-specific data if available
        machine_config = self.config.get("machines", {})
        machine_data = None
        
        # Try to find machine in the config
        if self.machine.name in machine_config:
            machine_data = machine_config[self.machine.name]
        # If not found, try the parent (if exists)
        elif self.machine.romof and self.machine.romof in machine_config:
            machine_data = machine_config[self.machine.romof]
            
        # Add machine data if found
        if machine_data:
            machine_part = ET.SubElement(roms_elem, "part")
            machine_part.text = machine_data
        else:
            # If no machine data found, raise a detailed error
            parent_info = f" (parent: {self.machine.romof})" if self.machine.romof else ""
            available_machines = ", ".join(sorted(machine_config.keys()))
            error_msg = (
                f"Machine '{self.machine.name}'{parent_info} not found in machines configuration.\n"
                f"Available machines in config: {available_machines}\n"
                f"Please add an entry for '{self.machine.name}' to the [machines] section in {self.config_file}"
            )
            raise ValueError(error_msg)
        
        # Group ROMs by region
        regions = {}
        unknown_regions = {}
        
        sprites_hi_roms = []
        
        # First pass - handle sprites_hi region specially
        for rom in self.machine.roms:
            if rom.region == "sprites_hi":
                sprites_hi_roms.append(rom)
            elif rom.region:
                if rom.region in self.region_map:
                    if rom.region not in regions:
                        regions[rom.region] = []
                    regions[rom.region].append(rom)
                else:
                    if rom.region not in unknown_regions:
                        unknown_regions[rom.region] = []
                    unknown_regions[rom.region].append(rom)
        
        # Check if we have both sprites and sprites_hi regions (special case)
        has_sprites_hi = len(sprites_hi_roms) > 0 and "sprites" in regions
        
        # Process known regions
        for region_name, region_roms in regions.items():
            # Sort ROMs by offset within the region
            region_roms.sort(key=lambda r: r.offset if r.offset is not None else 0)
            
            # Special handling for sprites region when sprites_hi exists
            if region_name == "sprites" and has_sprites_hi:
                self._process_sprites_with_hi(roms_elem, region_roms, sprites_hi_roms)
                continue
            
            # Calculate total size of all ROMs in this region
            total_size = sum(rom.size for rom in region_roms)
            
            # Get region info from mapping
            region_info = self.region_map[region_name]
            region_id = region_info["id"]
            
            # Add comment with region name and size in decimal
            comment_text = f"Region: {region_name}, Size: {total_size} bytes"
            comment = ET.Comment(comment_text)
            roms_elem.append(comment)
            
            # Create region header part with ID and size
            header_value = f"{region_id:02x}{total_size:06x}"
            header_part = ET.SubElement(roms_elem, "part")
            header_part.text = header_value
            
            # Add parts for each ROM in this region, handling interleaved ROMs
            i = 0
            while i < len(region_roms):
                rom = region_roms[i]
                
                # Check if this ROM and the next one are interleaved (offsets differ by 1)
                if (i + 1 < len(region_roms) and 
                    rom.offset is not None and 
                    region_roms[i + 1].offset is not None and 
                    abs(rom.offset - region_roms[i + 1].offset) == 1):
                    
                    # Create interleave tag
                    interleave = ET.SubElement(roms_elem, "interleave")
                    interleave.set("output", "16")
                    
                    # First ROM (even offset gets map="10", odd offset gets map="01")
                    first_rom = rom
                    second_rom = region_roms[i + 1]
                    
                    # Get swap flag for this region
                    swap = self.region_map[region_name].get("swap", False)
                    
                    # Determine the mapping based on offset parity and swap flag
                    if first_rom.offset % 2 == 0:  # Even offset
                        first_map = "01" if swap else "10"
                        second_map = "10" if swap else "01"
                    else:  # Odd offset
                        first_map = "10" if swap else "01"
                        second_map = "01" if swap else "10"
                    
                    # Add first part
                    first_part = ET.SubElement(interleave, "part")
                    if first_rom.crc:
                        first_part.set("crc", first_rom.crc)
                    first_part.set("name", first_rom.name)
                    first_part.set("map", first_map)
                    
                    # Add second part
                    second_part = ET.SubElement(interleave, "part")
                    if second_rom.crc:
                        second_part.set("crc", second_rom.crc)
                    second_part.set("name", second_rom.name)
                    second_part.set("map", second_map)
                    
                    # Skip the next ROM as we've already processed it
                    i += 2
                else:
                    # Regular non-interleaved ROM
                    part = ET.SubElement(roms_elem, "part")
                    if rom.crc:
                        part.set("crc", rom.crc)
                    part.set("name", rom.name)
                    i += 1
        
        # Add comments for unknown regions
        if unknown_regions:
            comment = ET.Comment("Unknown regions:")
            roms_elem.append(comment)
            
            for region_name, region_roms in unknown_regions.items():
                rom_details = [f"{rom.name} (size={rom.size}, crc={rom.crc})" for rom in region_roms]
                comment_text = f"Region '{region_name}': {', '.join(rom_details)}"
                comment = ET.Comment(comment_text)
                roms_elem.append(comment)
    
    def _process_sprites_with_hi(self, roms_elem, sprites_roms, sprites_hi_roms):
        """Special case processing for sprites + sprites_hi combination.
        
        In this case we expect:
        - 2 ROMs in the sprites region
        - 1 ROM in the sprites_hi region
        
        The sprites_hi ROM should be duplicated in the interleave with map="0100" and map="1000"
        """
        # Sort ROMs by offset within their respective regions
        sprites_roms.sort(key=lambda r: r.offset if r.offset is not None else 0)
        sprites_hi_roms.sort(key=lambda r: r.offset if r.offset is not None else 0)
        
        # Verify we have the expected number of ROMs
        if len(sprites_roms) == 2 and len(sprites_hi_roms) == 1:
            # Calculate total size, counting sprites_hi ROM twice (since we'll duplicate it)
            total_size = sum(rom.size for rom in sprites_roms)
            total_size += sprites_hi_roms[0].size * 2  # Count sprites_hi ROM twice
            
            # Get region info from mapping
            region_info = self.region_map["sprites"]
            region_id = region_info["id"]
            swap = region_info.get("swap", False)
            
            # Add comment explaining the special case
            comment_text = f"Region: sprites + sprites_hi (32-bit interleave), Size: {total_size} bytes"
            comment = ET.Comment(comment_text)
            roms_elem.append(comment)
            
            # Create region header part with ID and size
            header_value = f"{region_id:02x}{total_size:06x}"
            header_part = ET.SubElement(roms_elem, "part")
            header_part.text = header_value
            
            # Create 32-bit interleave
            interleave = ET.SubElement(roms_elem, "interleave")
            interleave.set("output", "32")
            
            # Determine the map values based on the swap flag
            if swap:
                sprite1_map = "0010"
                sprite2_map = "0001"
                sprites_hi1_map = "1000"
                sprites_hi2_map = "0100"
            else:
                sprite1_map = "0001"
                sprite2_map = "0010"
                sprites_hi1_map = "0100"
                sprites_hi2_map = "1000"
            
            # Add the first sprite ROM
            sprite1_part = ET.SubElement(interleave, "part")
            if sprites_roms[0].crc:
                sprite1_part.set("crc", sprites_roms[0].crc)
            sprite1_part.set("name", sprites_roms[0].name)
            sprite1_part.set("map", sprite1_map)
            
            # Add the second sprite ROM
            sprite2_part = ET.SubElement(interleave, "part")
            if sprites_roms[1].crc:
                sprite2_part.set("crc", sprites_roms[1].crc)
            sprite2_part.set("name", sprites_roms[1].name)
            sprite2_part.set("map", sprite2_map)
            
            # Add the sprites_hi ROM twice
            sprites_hi_part1 = ET.SubElement(interleave, "part")
            if sprites_hi_roms[0].crc:
                sprites_hi_part1.set("crc", sprites_hi_roms[0].crc)
            sprites_hi_part1.set("name", sprites_hi_roms[0].name)
            sprites_hi_part1.set("map", sprites_hi1_map)
            
            sprites_hi_part2 = ET.SubElement(interleave, "part")
            if sprites_hi_roms[0].crc:
                sprites_hi_part2.set("crc", sprites_hi_roms[0].crc)
            sprites_hi_part2.set("name", sprites_hi_roms[0].name)
            sprites_hi_part2.set("map", sprites_hi2_map)
        else:
            # Unexpected ROM count pattern - fallback to normal processing
            print(f"Warning: Unexpected ROM count in sprites ({len(sprites_roms)}) or sprites_hi ({len(sprites_hi_roms)}) regions.")
            print(f"Expected 2 sprites ROMs and 1 sprites_hi ROM. Reverting to standard processing.")
            
            # Calculate total size of sprites region only
            total_size = sum(rom.size for rom in sprites_roms)
            
            # Get region info from mapping
            region_info = self.region_map["sprites"]
            region_id = region_info["id"]
            
            # Add comment
            comment_text = f"Region: sprites, Size: {total_size} bytes"
            comment = ET.Comment(comment_text)
            roms_elem.append(comment)
            
            # Create region header part with ID and size
            header_value = f"{region_id:02x}{total_size:06x}"
            header_part = ET.SubElement(roms_elem, "part")
            header_part.text = header_value
            
            # Process sprites ROMs normally
            for rom in sprites_roms:
                part = ET.SubElement(roms_elem, "part")
                if rom.crc:
                    part.set("crc", rom.crc)
                part.set("name", rom.name)
    
    def _add_metadata(self, mra):
        """Add metadata from TOML config to the MRA."""
        # Get metadata from TOML
        metadata_config = self.config.get("metadata", {})
        
        # Collect metadata for this machine, falling back to parent or default
        metadata = {}
        
        # First try to get default metadata
        default_metadata = metadata_config.get("default", {})
        if isinstance(default_metadata, dict):
            metadata.update(default_metadata)
        
        # Next try parent metadata if available
        if self.machine.romof:
            parent_metadata = metadata_config.get(self.machine.romof, {})
            if isinstance(parent_metadata, dict):
                metadata.update(parent_metadata)
        
        # Finally get machine-specific metadata (overrides previous)
        machine_metadata = metadata_config.get(self.machine.name, {})
        if isinstance(machine_metadata, dict):
            metadata.update(machine_metadata)
        
        # Add all metadata as tags
        for key, value in metadata.items():
            self._add_child(mra, key, str(value))
    
    def _add_buttons_configuration(self, mra):
        """Add buttons configuration from TOML to the MRA."""
        # Get buttons config from TOML
        buttons_config = self.config.get("buttons", {})
        
        # Get SNES and GAME button configs
        snes_config = None
        game_config = None
        
        # Try to find machine-specific config
        if self.machine.name in buttons_config:
            machine_config = buttons_config[self.machine.name]
            if isinstance(machine_config, dict) and "snes" in machine_config and "game" in machine_config:
                snes_config = machine_config["snes"]
                game_config = machine_config["game"]
        
        # If not found, try parent
        if (snes_config is None or game_config is None) and self.machine.romof and self.machine.romof in buttons_config:
            parent_config = buttons_config[self.machine.romof]
            if isinstance(parent_config, dict) and "snes" in parent_config and "game" in parent_config:
                if snes_config is None:
                    snes_config = parent_config["snes"]
                if game_config is None:
                    game_config = parent_config["game"]
        
        # If still not found, use default
        if snes_config is None and "default" in buttons_config:
            default_config = buttons_config["default"]
            if isinstance(default_config, dict) and "snes" in default_config:
                snes_config = default_config["snes"]
        
        if game_config is None and "default" in buttons_config:
            default_config = buttons_config["default"]
            if isinstance(default_config, dict) and "game" in default_config:
                game_config = default_config["game"]
        
        # Add buttons tag if we have configs
        if snes_config or game_config:
            buttons = ET.SubElement(mra, "buttons")
            if snes_config:
                buttons.set("default", snes_config)
            if game_config:
                buttons.set("names", game_config)
    
    def _add_child(self, parent, tag, text):
        """Helper to add a child element with text to parent."""
        child = ET.SubElement(parent, tag)
        child.text = text
        return child
    
    def _prettify(self, elem):
        """Return a pretty-printed XML string for the Element."""
        
        # Convert element to string (raw)
        rough_string = ET.tostring(elem, 'utf-8')
        
        # Use minidom to prettify
        import xml.dom.minidom
        reparsed = xml.dom.minidom.parseString(rough_string)
        pretty_string = reparsed.toprettyxml(indent="\t")
        
        # Remove XML declaration that minidom adds
        if pretty_string.startswith('<?xml'):
            pretty_string = pretty_string.split('\n', 1)[1]
        
        # Remove extra blank lines that minidom adds
        pretty_string = '\n'.join([line for line in pretty_string.split('\n') if line.strip()])
        
        # ElementTree in Python sometimes abbreviates tag names, fix those
        pretty_string = pretty_string.replace("<n>", "<name>").replace("</n>", "</name>")
        
        return pretty_string


def _sanitize_makefile_path(description):
    """Sanitize a description for use in a Makefile path."""
    # Replace problematic characters
    result = description
    result = result.replace("'", "")
    result = result.replace('"', "")
    result = result.replace('/', '-')  # Replace slashes with hyphens
    result = result.replace(':', '-')  # Replace colons with hyphens
    result = result.replace(' ', '\\ ')  # Escape spaces
    result = result.replace('&', '\\&')  # Escape ampersands
    # Do not escape parentheses, commas, or plus signs
    return result

def _sanitize_makefile_target(path):
    """Sanitize a path for use as a Makefile target."""
    # Target names should not have parentheses escaped
    # This is important for Makefile compatibility
    return path

def generate_zip_list(machines, output_file=None):
    """Generate a list of all required ZIP files for the machines.
    
    Args:
        machines: List of Machine objects
        output_file: Path to output file. If None, the list is just returned as a string.
        
    Returns:
        A string containing the list of required ZIP files, one per line.
    """
    # Create a set of all required ZIP files
    required_zips = set()
    
    for machine in machines:
        # Add the machine's own ZIP
        required_zips.add(f"{machine.name}.zip")
        
        # Add the parent ZIP if needed
        if machine.romof:
            required_zips.add(f"{machine.romof}.zip")
    
    # Sort the list for consistent output
    zip_list = sorted(required_zips)
    zip_list_text = '\n'.join(zip_list)
    
    # Write to file if requested
    if output_file:
        with open(output_file, 'w') as f:
            f.write(zip_list_text)
    
    return zip_list_text


def generate_makefile_rules(machines, output_dir="releases"):
    """Generate Makefile rules for building MRA files."""
    rules = []
    
    # Add phony targets
    rules.append(".PHONY: mra clean_mra")
    rules.append("")
    
    # Add main mra target
    mra_targets = []
    for machine in machines:
        # Create a safe filename from the description
        desc = _sanitize_makefile_path(machine.description)
        target = f"{output_dir}/{desc}.mra"
        mra_targets.append(target)
    
    rules.append("# Generate all MRA files")
    rules.append(f"mra: {' '.join(mra_targets)}")
    rules.append("")
    
    # Add clean_mra target
    rules.append("# Clean MRA files")
    rules.append(f"clean_mra:")
    rules.append(f"\trm -f {output_dir}/*.mra")
    rules.append("")
    
    # Add directory creation
    rules.append(f"{output_dir}:")
    rules.append(f"\tmkdir -p {output_dir}")
    rules.append("")
    
    # Add individual MRA targets
    rules.append("# Individual MRA targets")
    for machine in machines:
        # Create a safe filename from the description
        desc = _sanitize_makefile_path(machine.description)
        target = f"{output_dir}/{desc}.mra"
        
        # Add the rule - no need to escape the target as parentheses should not be escaped in Makefile targets
        rules.append(f"{target}: {output_dir}")
        rules.append(f"\t$(PYTHON) util/mame2mra.py $(MAME_XML) --generate --machine {machine.name} --output {output_dir}")
        rules.append("")
    
    return "\n".join(rules)


def main():
    """Main function to test the parser and MRA generator."""
    parser = argparse.ArgumentParser(description="Parse MAME XML and generate MRA files for MiSTer")
    parser.add_argument("xml_file", help="Path to the MAME XML file")
    parser.add_argument("--generate", "-g", action="store_true", help="Generate MRA files")
    parser.add_argument("--machine", "-m", help="Process only the specified machine")
    parser.add_argument("--all-machines", "-a", action="store_true", help="Generate MRAs for all machines in the TOML machines section and their children")
    parser.add_argument("--output", "-o", default="mra", help="Output directory for MRA files")
    parser.add_argument("--core", "-c", default="TaitoF2", help="Core name (default: TaitoF2)")
    parser.add_argument("--rbf", "-r", help="RBF filename (defaults to core name)")
    parser.add_argument("--config", help="Path to TOML configuration file (default: mame2mra.toml in script directory)")
    parser.add_argument("--makefile", action="store_true", help="Generate Makefile rules for building MRA files")
    parser.add_argument("--zip-list", "-z", help="Generate a list of required ZIP files and write to the specified file (use '-' for stdout)")
    parser.add_argument("--filename-prefix", "-p", default="", help="Add a prefix to all generated MRA filenames")
    
    args = parser.parse_args()
    
    # Parse XML file
    mame_parser = MAMEParser(args.xml_file)
    machines = mame_parser.parse()
    
    # Load configuration to get machines list
    config_file = args.config or os.path.join(os.path.dirname(__file__), "mame2mra.toml")
    try:
        with open(config_file, "rb") as f:
            config = tomli.load(f)
    except Exception as e:
        print(f"Warning: Could not load configuration from {config_file}: {e}")
        config = {}
    
    # Filter machines based on arguments
    if args.all_machines:
        # Get all machines from TOML and their children
        toml_machines = config.get("machines", {}).keys()
        
        # Create a set to track processed machines
        selected_machines = set(toml_machines)
        
        # Find all clones of machines in the TOML
        for machine in machines:
            if machine.romof in selected_machines:
                selected_machines.add(machine.name)
        
        # Filter the machines list
        machines = [m for m in machines if m.name in selected_machines]
        print(f"Selected {len(machines)} machines from TOML config and their children")
    elif args.machine:
        # Single machine mode
        machines = [m for m in machines if m.name == args.machine]
        if not machines:
            print(f"Machine '{args.machine}' not found in XML file")
            return
    
    # Handle different operation modes
    if args.zip_list:
        # Generate a list of required ZIP files
        output_file = None if args.zip_list == '-' else args.zip_list
        zip_list = generate_zip_list(machines, output_file)
        
        if args.zip_list == '-':
            # Print to stdout
            print(zip_list)
        else:
            print(f"Generated ZIP list with {len(zip_list.splitlines())} entries in: {args.zip_list}")
    elif args.makefile:
        # Generate Makefile rules
        rules = generate_makefile_rules(machines, args.output)
        print(rules)
    elif args.generate:
        # Generate MRA files
        print(f"Generating MRA files in directory: {args.output}")
        successful = 0
        failed = 0
        
        for machine in machines:
            try:
                generator = MRAGenerator(
                    machine=machine,
                    core_name=args.core,
                    output_dir=args.output,
                    rbf=args.rbf,
                    config_file=args.config,
                    filename_prefix=args.filename_prefix
                )
                output_file = generator.generate_mra()
                print(f"Generated MRA for {machine.name}: {output_file}")
                successful += 1
            except Exception as e:
                print(f"Error generating MRA for {machine.name}: {e}")
                failed += 1
        
        print(f"Generation complete: {successful} successful, {failed} failed")
    else:
        # Just print information about the machines
        print(f"Parsed {len(machines)} machines")
        for i, machine in enumerate(machines[:5]):  # Show first 5 for brevity
            print(f"\nMachine {i+1}: {machine.name}")
            print(f"  Description: {machine.description}")
            print(f"  Year: {machine.year}")
            print(f"  Manufacturer: {machine.manufacturer}")
            print(f"  ROMs: {len(machine.roms)}")
            for j, rom in enumerate(machine.roms[:3]):  # Show first 3 ROMs
                print(f"    ROM {j+1}: {rom.name}, CRC: {rom.crc}, Region: {rom.region}")
            print(f"  Displays: {len(machine.displays)}")
            print(f"  Dipswitches: {len(machine.dipswitches)}")
        
        if len(machines) > 5:
            print(f"\n... and {len(machines) - 5} more")


if __name__ == "__main__":
    main()
