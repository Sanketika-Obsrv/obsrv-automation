package utils

import "strings"

// Validating metrics name
// Input a list of string, and concatinate with _ after
// Removing all - in the provided names
// Convert mix cases to lowercases
func MetricsNameValidator(names ...string) string {
	retName := ""
	for _, name := range names {
		retName += strings.ReplaceAll(name, "-", "_") + "_"
	}
	return strings.ToLower(strings.TrimRight(retName, "_"))
}
