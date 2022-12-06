package main

import (
	"crypto/sha256"
	"io"
	"log"
	"os"
)

func main() {
	h := sha256.New()
	out, err := os.Create(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer out.Close()
	for _, filename := range os.Args[2:] {
		f, err := os.Open(filename)
		if err != nil {
			log.Fatal(err)
		}
		defer f.Close()
		if _, err := io.Copy(h, f); err != nil {
			log.Fatal(err)
		}
	}
	if _, err := out.Write(h.Sum(nil)); err != nil {
		log.Fatal(err)
	}
}
