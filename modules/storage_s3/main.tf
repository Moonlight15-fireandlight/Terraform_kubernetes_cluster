data "aws_s3_bucket" "photos_bucket" {

    bucket = "fotosfamiliamoralesbellido"
  
}

locals {

  object_source = "C:/Users/Paul/Downloads/TAMBO-05-2014-20250301T211333Z-001.zip"

}

resource "aws_s3_object" "object_photos" {
    bucket = data.aws_s3_bucket.photos_bucket.bucket
    key    = "Fotos_tambo_2014"
    source = "C:/Users/Paul/Downloads/TAMBO-05-2014"
    source_hash = filemd5(local.object_source)
}