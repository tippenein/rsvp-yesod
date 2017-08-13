module Api.V3.MailGun where

import           Prelude (String, IO, ($), map, return)

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as LBS
import           Data.Maybe
import           Data.Monoid ((<>))
import           Data.Text (Text, intercalate, unpack)
import           Data.Text.Encoding (encodeUtf8)
import           Network.HTTP.Client.MultipartFormData
import           Network.HTTP.Conduit
import           Network.Mail.Mime (Address(..), Mail(..), renderMail')

addressToText :: Address -> Text
addressToText address =
    maybe "" (<> " ") (addressName address) <> "<" <> addressEmail address <> ">"

sendMailGun :: Text          -- ^ domain
            -> String
            -> Manager       -- ^ re-use an existing http manager
            -> Mail
            -> IO (Response LBS.ByteString)
sendMailGun domain mailgunKey httpMan email = do
    bs <- renderMail' email
    request <- parseRequest $ unpack $ "https://api.mailgun.net/v3/" <> domain <> "/messages.mime"
    preq <- postRequest (LBS.toStrict bs) request
    httpLbs (auth (C8.pack mailgunKey) preq) httpMan
  where
    to = encodeUtf8 $ intercalate "," $ map addressToText $ mailTo email
    auth key = applyBasicAuth "api" key
    postRequest message = formDataBody
      [ partBS "to" to
      , partFileBS "message" message
      ]

-- | similar to 'partFile', but useful if you have the file contents already in memory
-- Normally you would use partBS, but an API may require the parameter to be a file
partFileBS :: Text -> BS.ByteString -> Part
partFileBS n fileContents = partFileRequestBodyM n (unpack n) $
        return $ RequestBodyBS fileContents