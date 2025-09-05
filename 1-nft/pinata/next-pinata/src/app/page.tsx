"use client";

import { useState } from "react";
import { Upload, Loader2, Image as ImageIcon } from "lucide-react";
import { ethers } from "ethers";
import abi from "./abi.json";

const CONTRACT_ADDRESS = "0x06269E8c9B09245C01c8d60bB478AeeA0B3089fB";

declare global {
  interface Window {
    ethereum?: any;
  }
}

export default function Home() {
  const [file, setFile] = useState<File>();
  const [url, setUrl] = useState("");
  const [uploading, setUploading] = useState(false);

  const [nftName, setNftName] = useState("");
  const [nftDescription, setNftDescription] = useState("");

  const [metadataUrl, setMetadataUrl] = useState("");

  const [minting, setMinting] = useState(false);

  const uploadFile = async () => {
    try {
      if (!file) {
        alert("No file selected");
        return;
      }

      setUploading(true);
      const data = new FormData();
      data.set("file", file);
      const uploadRequest = await fetch("/api/files", {
        method: "POST",
        body: data,
      });
      const signedUrl = await uploadRequest.json();
      setUrl(signedUrl);
      setUploading(false);
    } catch (e) {
      console.log(e);
      setUploading(false);
      alert("Trouble uploading file");
    }
  };

  const uploadMetadata = async () => {
    try {
      if (!url || !nftName || !nftDescription) {
        alert("Please upload image and fill in NFT details first");
        return;
      }

      setUploading(true);

      // Create metadata object
      const metadata = {
        name: nftName,
        description: nftDescription,
        image: url.replace('https://', 'ipfs://').replace('.mypinata.cloud/ipfs/', '/'),
      };

      // Upload metadata as JSON
      const metadataBlob = new Blob([JSON.stringify(metadata)], {
        type: 'application/json'
      });

      const formData = new FormData();
      formData.append('file', metadataBlob, 'metadata.json');

      const metadataRequest = await fetch("/api/files", {
        method: "POST",
        body: formData,
      });

      const metadataSignedUrl = await metadataRequest.json();
      setMetadataUrl(metadataSignedUrl);
      setUploading(false);

    } catch (e) {
      console.log(e);
      setUploading(false);
      alert("Trouble uploading metadata");
    }
  };

  const mintNFT = async () => {
    try {
      if (!metadataUrl) {
        alert("Please upload metadata first");
        return;
      }

      setMinting(true);

      // Check if MetaMask is installed
      if (typeof window.ethereum === 'undefined') {
        alert("Please install MetaMask");
        return;
      }

      // Request account access
      await window.ethereum.request({ method: 'eth_requestAccounts' });

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, signer);

      // Convert metadata URL to IPFS format
      const tokenURI = metadataUrl.replace('https://magenta-calm-ostrich-237.mypinata.cloud/ipfs/', 'ipfs://');

      const userAddress = await signer.getAddress();

      // Call mintNFT function
      const tx = await contract.mintNFT(userAddress, tokenURI);

      console.log("Transaction hash:", tx.hash);
      alert(`Transaction sent! Hash: ${tx.hash}`);

      // Wait for confirmation
      await tx.wait();
      alert("NFT minted successfully!");
      setMinting(false);

    } catch (e) {
      console.log(e);
      setMinting(false);
      alert("Error minting NFT");
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFile(e.target?.files?.[0]);
  };

  return (
    <main className="w-full min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white p-6">
      <div className="w-full max-w-md p-8 rounded-2xl shadow-lg bg-gray-900 border border-gray-700">
        <h1 className="text-2xl font-bold text-center mb-6">Upload your file</h1>

        {/* File Input Box */}
        <label
          className="flex flex-col items-center justify-center w-full h-40 border-2 border-dashed border-gray-600 rounded-xl cursor-pointer hover:border-blue-500 transition"
        >
          <input type="file" className="hidden" onChange={handleChange} />
          <Upload className="w-10 h-10 text-gray-400 mb-2" />
          <span className="text-sm text-gray-400">
            {file ? file.name : "Click to select a file"}
          </span>
        </label>

        {/* Upload Button */}
        <button
          type="button"
          onClick={uploadFile}
          disabled={uploading}
          className="mt-6 w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-xl shadow-md transition disabled:opacity-50"
        >
          {uploading ? (
            <>
              <Loader2 className="animate-spin w-5 h-5" /> Uploading...
            </>
          ) : (
            <>
              <Upload className="w-5 h-5" /> Upload
            </>
          )}
        </button>

        {/* Uploaded Image Preview */}
        {url && (
          <div className="mt-6">
            <h1>{url}</h1>
            <h2 className="text-lg font-semibold mb-3">Preview</h2>
            <div className="rounded-xl overflow-hidden shadow-md">
              <img
                src={url}
                alt="Uploaded from Pinata"
                className="w-full h-64 object-cover"
              />
            </div>
          </div>
        )}
        {/* NFT Metadata Form - Add this after the image preview */}
        {url && (
          <div className="mt-6">
            <h2 className="text-lg font-semibold mb-3">NFT Details</h2>

            <input
              type="text"
              placeholder="NFT Name"
              value={nftName}
              onChange={(e) => setNftName(e.target.value)}
              className="w-full p-3 mb-3 bg-gray-800 border border-gray-600 rounded-xl text-white"
            />

            <textarea
              placeholder="NFT Description"
              value={nftDescription}
              onChange={(e) => setNftDescription(e.target.value)}
              className="w-full p-3 bg-gray-800 border border-gray-600 rounded-xl text-white h-24"
            />

            <button
              type="button"
              onClick={uploadMetadata}
              disabled={uploading || !nftName || !nftDescription}
              className="mt-4 w-full flex items-center justify-center gap-2 bg-purple-600 hover:bg-purple-700 text-white font-semibold py-2 px-4 rounded-xl shadow-md transition disabled:opacity-50"
            >
              {uploading ? (
                <>
                  <Loader2 className="animate-spin w-5 h-5" /> Uploading Metadata...
                </>
              ) : (
                "Upload Metadata"
              )}
            </button>

            <h1>{metadataUrl}</h1>

            {metadataUrl && (
              <p className="text-sm text-green-400 mt-2">✅ Metadata uploaded successfully!</p>
            )}
          </div>
        )}
        {metadataUrl && (
          <button
            type="button"
            onClick={mintNFT}
            disabled={minting}
            className="mt-4 w-full flex items-center justify-center gap-2 bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-4 rounded-xl shadow-md transition disabled:opacity-50"
          >
            {minting ? (
              <>
                <Loader2 className="animate-spin w-5 h-5" /> Minting NFT...
              </>
            ) : (
              "🚀 Mint NFT"
            )}
          </button>
        )}
      </div>
    </main>
  );
}
