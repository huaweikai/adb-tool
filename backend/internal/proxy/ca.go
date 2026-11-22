package proxy

import (
	"crypto/x509"
	"encoding/pem"
)

// CA wraps the root certificate authority for the proxy.
type CA struct {
	rootCert *x509.Certificate
}

// NewCAFromCert creates a new CA wrapper around the provided root certificate.
func NewCAFromCert(cert *x509.Certificate) *CA {
	return &CA{rootCert: cert}
}

// GetCACertPEM returns the PEM-encoded CA certificate.
func (c *CA) GetCACertPEM() []byte {
	if c == nil || c.rootCert == nil {
		return nil
	}
	return pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: c.rootCert.Raw,
	})
}

// GetCACertDER returns the raw DER bytes of the CA certificate.
func (c *CA) GetCACertDER() []byte {
	if c == nil || c.rootCert == nil {
		return nil
	}
	return c.rootCert.Raw
}
