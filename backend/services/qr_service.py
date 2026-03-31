import uuid

def generate_qr():
    # Only generate the unique token. 
    # The actual QR barcode image is drawn by the Flutter app.
    token = str(uuid.uuid4())
    
    return token, None