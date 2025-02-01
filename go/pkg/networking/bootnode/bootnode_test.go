package bootnode

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewBootNode(t *testing.T) {
	const enode = "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303"

	_, err := NewBootNode(enode)
	assert.Nil(t, err)
}
