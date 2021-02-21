



# TODO [ ] Replace this function with Get-StringHash() ?
function getSHA1($data) {
    
    $hash = [System.Security.Cryptography.SHA1CryptoServiceProvider]::new()    
    return getStringFromByte -byteArray $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($data))

}