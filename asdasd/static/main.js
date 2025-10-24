async function decrypt() {
  let algorithm = document.getElementById("algorithm").value;
  let key = document.getElementById("key").value;
  let text = document.getElementById("inputText").value;

  let res = await fetch("/decrypt", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({algorithm, key, text})
  });
  let data = await res.json();
  document.getElementById("outputText").value = data.result;
}

// File encrypt
async function encryptFile() {
  let fileInput = document.getElementById("inputFile");
  let algorithm = document.getElementById("fileAlgorithm").value;
  let key = document.getElementById("fileKey").value;
  let deleteOriginal = document.getElementById("deleteOriginal").checked;

  if (!fileInput.files.length) {
    alert("Chọn file trước!");
    return;
  }

  let formData = new FormData();
  formData.append("file", fileInput.files[0]);
  formData.append("algorithm", algorithm);
  formData.append("key", key);
  formData.append("deleteOriginal", deleteOriginal);

  let res = await fetch("/encrypt_file", {
    method: "POST",
    body: formData
  });

  let blob = await res.blob();
  let url = window.URL.createObjectURL(blob);
  let a = document.createElement("a");
  a.href = url;
  a.download = "encrypted_" + fileInput.files[0].name;
  a.click();
}

// File decrypt
async function decryptFile() {
  let fileInput = document.getElementById("inputFile");
  let algorithm = document.getElementById("fileAlgorithm").value;
  let key = document.getElementById("fileKey").value;
  let deleteOriginal = document.getElementById("deleteOriginal").checked;

  if (!fileInput.files.length) {
    alert("Chọn file trước!");
    return;
  }

  let formData = new FormData();
  formData.append("file", fileInput.files[0]);
  formData.append("algorithm", algorithm);
  formData.append("key", key);
  formData.append("deleteOriginal", deleteOriginal);

  let res = await fetch("/decrypt_file", {
    method: "POST",
    body: formData
  });

  let blob = await res.blob();
  let url = window.URL.createObjectURL(blob);
  let a = document.createElement("a");
  a.href = url;
  a.download = "decrypted_" + fileInput.files[0].name;
  a.click();
}
