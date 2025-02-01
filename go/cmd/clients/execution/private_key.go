package main

import (
	"context"
	"crypto/ecdsa"
	"log/slog"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/utils/assert"
	"github.com/ethereum/go-ethereum/crypto"
)

const PRIVATE_KEY_FILE = "./outputs/private.key"

func getPrivateKey(ctx context.Context) *ecdsa.PrivateKey {
	privateKey, err := crypto.LoadECDSA(PRIVATE_KEY_FILE)
	if err == nil {
		slog.InfoContext(ctx,
			"Detected existing private key in file",
			slog.String("file", PRIVATE_KEY_FILE),
		)
		return privateKey
	}

	privateKey, err = crypto.GenerateKey()
	assert.AssertErrNil(ctx, err, "Failed generating node's private key")

	err = crypto.SaveECDSA("./outputs/private.key", privateKey)
	assert.AssertErrNil(ctx, err,
		"Failed saving node's private key",
		slog.String("file", PRIVATE_KEY_FILE),
	)

	slog.InfoContext(ctx, "Generated and saved node's private key")

	return privateKey
}
