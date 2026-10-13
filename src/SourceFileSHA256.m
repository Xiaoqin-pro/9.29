function hash=SourceFileSHA256(path)
% Hash exact source bytes, including BOM/newlines, for preflight binding.
fid=fopen(path,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(bytes,'int8'));
digest=typecast(md.digest(),'uint8');hash=lower(reshape(dec2hex(digest,2).',1,[]));
end
