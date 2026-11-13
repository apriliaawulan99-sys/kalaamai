export function jsonError(message:string,status:number){return Response.json({error:message},{status})}
export async function readJsonBody(request:Request,maxBytes=16_384):Promise<{success:true;data:unknown}|{success:false;status:400|413}>{
  const contentLength=Number(request.headers.get("content-length")||0);
  if(Number.isFinite(contentLength)&&contentLength>maxBytes)return {success:false,status:413};
  let raw="";
  try{raw=await request.text()}catch{return {success:false,status:400}}
  if(new TextEncoder().encode(raw).byteLength>maxBytes)return {success:false,status:413};
  try{return {success:true,data:JSON.parse(raw) as unknown}}catch{return {success:false,status:400}}
}
