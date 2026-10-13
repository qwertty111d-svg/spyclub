// rbxverify compares binary places through the independent RobloxAPI/rbxfile decoder.
// Input files must have uncompressed chunks because rbxfile does not decode Zstandard.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"

	"github.com/robloxapi/rbxfile"
	"github.com/robloxapi/rbxfile/rbxl"
)

type item struct {
	Class      string            `json:"class"`
	Properties map[string]string `json:"properties"`
}

type snapshot struct {
	Items   map[string]item
	Sources map[string]string
	Warning string
}

func read(path string) (snapshot, error) {
	file, err := os.Open(path)
	if err != nil {
		return snapshot{}, err
	}
	defer file.Close()
	root, warn, err := (rbxl.Decoder{}).Decode(file)
	if err != nil {
		return snapshot{}, err
	}
	s := snapshot{Items: map[string]item{}, Sources: map[string]string{}}
	if warn != nil {
		s.Warning = warn.Error()
	}
	paths := map[*rbxfile.Instance]string{}
	var assign func([]*rbxfile.Instance, string)
	assign = func(instances []*rbxfile.Instance, parent string) {
		names := map[string]int{}
		for _, inst := range instances {
			instanceName := inst.ClassName
			if value, ok := inst.Properties["Name"]; ok {
				instanceName = value.String()
			}
			name := inst.ClassName + ":" + instanceName
			ordinal := names[name]
			names[name]++
			path := fmt.Sprintf("%s/%s[%d]", parent, name, ordinal)
			paths[inst] = path
			assign(inst.Children, path)
		}
	}
	assign(root.Instances, "")
	for inst, path := range paths {
		properties := map[string]string{}
		keys := make([]string, 0, len(inst.Properties))
		for key := range inst.Properties {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			value := inst.Properties[key]
			if key == "Source" {
				s.Sources[path] = value.String()
				continue
			}
			if ref, ok := value.(rbxfile.ValueReference); ok {
				properties[key] = "Reference:" + paths[ref.Instance]
			} else {
				properties[key] = value.Type().String() + ":" + value.String()
			}
		}
		s.Items[path] = item{Class: inst.ClassName, Properties: properties}
	}
	return s, nil
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: rbxverify original-uncompressed.rbxl output-uncompressed.rbxl")
		os.Exit(2)
	}
	before, err := read(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	after, err := read(os.Args[2])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if before.Warning != after.Warning {
		fmt.Fprintln(os.Stderr, "decoder warning set changed after patching")
		os.Exit(1)
	}
	propertyCount := 0
	for path, old := range before.Items {
		current, ok := after.Items[path]
		if !ok {
			fmt.Fprintln(os.Stderr, "original instance missing:", path)
			os.Exit(1)
		}
		oldJSON, _ := json.Marshal(old)
		newJSON, _ := json.Marshal(current)
		if string(oldJSON) != string(newJSON) {
			fmt.Fprintln(os.Stderr, "original non-source property difference:", path)
			os.Exit(1)
		}
		propertyCount += len(old.Properties)
	}
	changed := []string{}
	for path, old := range before.Sources {
		if old != after.Sources[path] {
			changed = append(changed, path)
		}
	}
	sort.Strings(changed)
	output := map[string]interface{}{"decoder": "github.com/robloxapi/rbxfile/rbxl", "original_instances": len(before.Items), "output_instances": len(after.Items),
		"original_non_source_properties_compared": propertyCount, "original_non_source_properties_identical": true, "changed_sources": changed,
		"decoder_warnings_identical": true,
		"original_decoder_warning":   before.Warning, "output_decoder_warning": after.Warning}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	encoder.Encode(output)
}
