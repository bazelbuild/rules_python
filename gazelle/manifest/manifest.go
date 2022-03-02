package manifest

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"

	yaml "gopkg.in/yaml.v2"
)

// File represents the gazelle_python.yaml file.
type File struct {
	Manifest *Manifest `yaml:"manifest,omitempty"`
	// Integrity is the hash of the requirements.txt file and the Manifest for
	// ensuring the integrity of the entire gazelle_python.yaml file. This
	// controls the testing to keep the gazelle_python.yaml file up-to-date.
	Integrity string `yaml:"integrity"`
}

// NewFile creates a new File with a given Manifest.
func NewFile(manifest *Manifest) *File {
	return &File{Manifest: manifest}
}

// Encode encodes the manifest file to the given writer.
func (f *File) Encode(w io.Writer, requirementsPath string) error {
	requirementsChecksum, err := sha256File(requirementsPath)
	if err != nil {
		return fmt.Errorf("failed to encode manifest file: %w", err)
	}
	integrityBytes, err := f.calculateIntegrity(requirementsChecksum)
	if err != nil {
		return fmt.Errorf("failed to encode manifest file: %w", err)
	}
	f.Integrity = fmt.Sprintf("%x", integrityBytes)
	encoder := yaml.NewEncoder(w)
	defer encoder.Close()
	if err := encoder.Encode(f); err != nil {
		return fmt.Errorf("failed to encode manifest file: %w", err)
	}
	return nil
}

// VerifyIntegrity verifies if the integrity set in the File is valid.
func (f *File) VerifyIntegrity(requirementsPath string) (bool, error) {
	requirementsChecksum, err := sha256File(requirementsPath)
	if err != nil {
		return false, fmt.Errorf("failed to verify integrity: %w", err)
	}
	integrityBytes, err := f.calculateIntegrity(requirementsChecksum)
	if err != nil {
		return false, fmt.Errorf("failed to verify integrity: %w", err)
	}
	valid := (f.Integrity == fmt.Sprintf("%x", integrityBytes))
	return valid, nil
}

// calculateIntegrity calculates the integrity of the manifest file based on the
// provided checksum for the requirements.txt file used as input to the modules
// mapping, plus the manifest structure in the manifest file. This integrity
// calculation ensures the manifest files are kept up-to-date.
func (f *File) calculateIntegrity(requirementsChecksum []byte) ([]byte, error) {
	hash := sha256.New()

	// Sum the manifest part of the file.
	encoder := yaml.NewEncoder(hash)
	defer encoder.Close()
	if err := encoder.Encode(f.Manifest); err != nil {
		return nil, fmt.Errorf("failed to calculate integrity: %w", err)
	}

	// Sum the requirements.txt checksum bytes.
	if _, err := hash.Write(requirementsChecksum); err != nil {
		return nil, fmt.Errorf("failed to calculate integrity: %w", err)
	}

	return hash.Sum(nil), nil
}

// Decode decodes the manifest file from the given path.
func (f *File) Decode(manifestPath string) error {
	file, err := os.Open(manifestPath)
	if err != nil {
		return fmt.Errorf("failed to decode manifest file: %w", err)
	}
	defer file.Close()

	decoder := yaml.NewDecoder(file)
	if err := decoder.Decode(f); err != nil {
		return fmt.Errorf("failed to decode manifest file: %w", err)
	}

	return nil
}

// Manifest represents the structure of the Gazelle manifest file.
type Manifest struct {
	// ModulesMapping is the mapping from importable modules to which Python
	// wheel name provides these modules.
	ModulesMapping map[string]string `yaml:"modules_mapping"`
	// PipDepsRepositoryName is the name of the pip_install repository target.
	// DEPRECATED
	PipDepsRepositoryName string `yaml:"pip_deps_repository_name,omitempty"`
	// PipRepository contains the information for pip_install or pip_repository
	// target.
	PipRepository *PipRepository `yaml:"pip_repository,omitempty"`
}

type PipRepository struct {
	// The name of the pip_install or pip_repository target.
	Name string
	// The incremental property of pip_repository.
	Incremental bool
}

// sha256File calculates the checksum of a given file path.
func sha256File(filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate sha256 sum for file: %w", err)
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return nil, fmt.Errorf("failed to calculate sha256 sum for file: %w", err)
	}

	return hash.Sum(nil), nil
}
