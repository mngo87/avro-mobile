package com.flurry.avroserver;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.mongodb.*;
import com.mongodb.DBCollection;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericDatumReader;
import org.apache.avro.generic.GenericRecord;
import org.apache.avro.io.BinaryEncoder;
import org.apache.avro.io.DatumReader;
import org.apache.avro.io.Decoder;
import org.apache.avro.io.DecoderFactory;
import org.apache.avro.io.EncoderFactory;
import org.apache.avro.io.JsonEncoder;
import org.apache.avro.specific.SpecificDatumReader;
import org.apache.avro.specific.SpecificDatumWriter;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.AbstractHandler;
import org.eclipse.jetty.server.handler.ContextHandler;
import org.eclipse.jetty.server.handler.ContextHandlerCollection;
import org.eclipse.jetty.util.StringUtil;

import com.flurry.avroserver.protocol.v1.Ad;
import com.flurry.avroserver.protocol.v1.AdRequest;
import com.flurry.avroserver.protocol.v1.AdResponse;

import com.mongodb.util.JSON;
import org.bson.Document;

/**
 * This lightweight avro server provides a web interface for remote
 * applications. Intended to illustrate receiving and parsing an Avro request
 * followed by constructing and encoding an Avro response. Supports both Avro
 * binary and JSON.
 * 
 * @author anthony@flurry
 */
public class
		AvroServer {

	private static Server server = null;
	protected static DecoderFactory DECODER_FACTORY = new DecoderFactory();
	protected static final String JSON_CONTENT_TYPE = "application/json";
	protected static final String BINARY_CONTENT_TYPE = "avro/binary";

	private static final String schemaRepoUrl = "http://localhost:2876/schema-repo";

	private HashMap<String, HashMap<Integer,String>> schemaCache;
	private MongoClient mongoClient;

	private final int serverSchemaVersion = 1;

	private AvroServer() {
		schemaCache = new HashMap<String, HashMap<Integer,String>>();

		mongoClient = new MongoClient( "localhost" , 27017 );
		try {
			processSchemaFromDB();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public static void main(String[] args) {
		try {
			if (args.length == 1) {
				int httpport;

				try {
					httpport = Integer.parseInt(args[0]);
				} catch (NumberFormatException e) {
					throw new IllegalArgumentException(
							"Must provide valid http port.");
				}

				AvroServer avroServer = new AvroServer();

				server = new Server(httpport);

				ContextHandlerCollection contexts = new ContextHandlerCollection();

				ContextHandler context = new ContextHandler();
				context.setContextPath("/");
				context.setResourceBase(".");
				context.setClassLoader(Thread.currentThread()
						.getContextClassLoader());
				context.setHandler(new WebHandler(avroServer));
				contexts.addHandler(context);

				server.setHandler(contexts);

				server.setGracefulShutdown(1000);
				server.setStopAtShutdown(true);

				server.start(); // spawns a new thread.
				server.join();
			} else {
				System.out.println("usage: java AvroServer <http port>");
			}
		} catch (Exception e) {
			System.err.println("Catastrophic failure " + e.getMessage());
			System.exit(1);
		}
		System.exit(0);
	}

	private String fetchSchema(String schemaName, int schemaVersion) {
		String fetchedSchema = null;
		HashMap<Integer,String> schemas = schemaCache.get(schemaName);
		if (schemas == null) {
			schemaCache.put(schemaName, new HashMap<Integer,String>());
		} else {
			fetchedSchema = schemas.get(schemaVersion);
		}

		if (fetchedSchema == null) {
			String fetchedSchemaStr = null;
			try {
				URL url = new URL(schemaRepoUrl + "/" + schemaName + "/id/" + schemaVersion);
				HttpURLConnection conn;

				//fix
				conn = (HttpURLConnection) url.openConnection();
				conn.setRequestMethod("GET");

				//fire request
				BufferedReader reader = new BufferedReader(
						new InputStreamReader(conn.getInputStream()));
				if (conn.getResponseCode() == HttpURLConnection.HTTP_OK) {

					String inputLine;
					StringBuffer result = new StringBuffer();
					while ((inputLine = reader.readLine()) != null) {
						result.append(inputLine);
					}
					reader.close();

					fetchedSchemaStr = result.toString();
					System.out.println("fetchedSchemaStr="+fetchedSchemaStr);
				}
			} catch (IOException e) {
				e.printStackTrace();
			} finally {

			}

			if (fetchedSchemaStr != null) {
				schemas = schemaCache.get(schemaName);
				schemas.put(schemaVersion, fetchedSchemaStr);
				fetchedSchema = fetchedSchemaStr;
				System.out.println("Updated schema cache for "+schemaName);
			} else {
				System.out.println("Fail to fetch for "+schemaName+" version:"+schemaVersion);
			}
		}
		return fetchedSchema;
	}

	protected GenericRecord readRequest(InputStream is,
								String contentType,
								String schemaName,
								int schemaVersion)
			throws IOException, IllegalArgumentException {

		GenericRecord record = null;
		System.out.println("MIKE contentType="+contentType);
		System.out.println("MIKE schemaName="+schemaName);
		System.out.println("MIKE schemaVersion="+schemaVersion);

		if (contentType == null) {
			throw new IOException("Content type not set for Request");
		}

		//schema used by client (writer)
		String requestSchemaStr = fetchSchema(schemaName, schemaVersion);
		if (requestSchemaStr == null) {
			throw new IllegalArgumentException("No schema found for "+schemaName+" version:"+schemaVersion);
		}
		Schema requestSchema = new Schema.Parser().parse(requestSchemaStr);

		//use newest server (reader) for updates to force all updates to conform to newest schema
		String readerSchemaStr = fetchSchema(schemaName, serverSchemaVersion);
		if (readerSchemaStr == null) {
			throw new IllegalArgumentException("No schema found for "+schemaName+" version:"+serverSchemaVersion);
		}
		Schema readerSchema = new Schema.Parser().parse(readerSchemaStr);

		Decoder decoder = null;
		if (contentType.equals(BINARY_CONTENT_TYPE)) {
			decoder = DECODER_FACTORY.binaryDecoder(is, null);
		} else if (contentType.equals(JSON_CONTENT_TYPE)) {
			decoder = DECODER_FACTORY.jsonDecoder(requestSchema, is);
		} else {
			throw new IOException("Unknown content type for Request");
		}

		//translate to readerSchema (newest server version)
		DatumReader<GenericRecord> datumReader = new GenericDatumReader<GenericRecord>(requestSchema, readerSchema);
		try {
			// Should only be 1 request object
			record = datumReader.read(null, decoder);

			System.out.println("Generic Read Request: " + record);
		} catch (EOFException eof) {
			eof.printStackTrace();
			System.err.println("End of file: " + eof.getMessage());
		} catch (Exception ex) {
			System.err
					.println("Error in processing request " + ex.getMessage());
		}

		//written as server's version of schema
		insertToMongoDB("userPref", record.toString(), serverSchemaVersion);
		return record;
	}

	//TODO: need to persist incoming (request) schema
	private void processSchemaFromDB() throws IOException {
		String schemaName = "UserPref";

		Document doc = readFromMongoDB("userPref", 34);
		int schemaVersion = doc.getInteger("schemaVersion");

		String writtenSchemaStr = fetchSchema(schemaName, schemaVersion);
		Schema writtenSchema = new Schema.Parser().parse(writtenSchemaStr);

		int clientSchemaVersion = 1;
		String clientSchemaStr = fetchSchema(schemaName, clientSchemaVersion);
		Schema clientSchema = new Schema.Parser().parse(clientSchemaStr);

		System.out.println("doc toString="+doc.toJson());

		//remove version
		//no need cause reconciled read will decode
		//stored as json, so don't need to remove extra fields
		//if not then remove extra field
		Decoder decoder = DECODER_FACTORY.jsonDecoder(writtenSchema, doc.toJson());
		//writer, reader
		DatumReader<GenericRecord> datumReader = new GenericDatumReader<GenericRecord>(writtenSchema, clientSchema);
		//should do the translation for what mobile client sees
		GenericRecord reconciledRecord = datumReader.read(null, decoder);
		System.out.println("Reconciled record: "+reconciledRecord);
	}

	private void insertToMongoDB(String collection, String jsonStr, int schemaVersion) {
		MongoDatabase db = mongoClient.getDatabase("poc");

		MongoCollection<Document> coll = db.getCollection(collection);

		// convert JSON to DBObject directly
		DBObject dbObject = (DBObject) JSON.parse(jsonStr);
		dbObject.put("schemaVersion", schemaVersion);
		Document doc = new Document(dbObject.toMap());

		coll.insertOne(doc);
	}

	private Document readFromMongoDB(String collection, long userId) {
		MongoDatabase db = mongoClient.getDatabase("poc");
		FindIterable<Document> iterable = db.getCollection(collection)
				.find(new Document("userId", userId));
		Document result = iterable.first();
		return result;
//		iterable.forEach(new Block<Document>() {
//			@Override
//			public void apply(final Document document) {
//				System.out.println(document);
//			}
//		});
	}

	protected AdRequest readRequest(InputStream is, String contentType)
			throws IOException {
		AdRequest adRequest = null;

		Decoder decoder = null;
		if (contentType == null) {
			throw new IOException("Content type not set for Ad Request");
		}

		if (contentType.equals(BINARY_CONTENT_TYPE)) {
			decoder = DECODER_FACTORY.binaryDecoder(is, null);
		} else if (contentType.equals(JSON_CONTENT_TYPE)) {
			decoder = DECODER_FACTORY.jsonDecoder(AdRequest.SCHEMA$, is);
		} else {
			throw new IOException("Unknown content type for Ad Request");

		}

		SpecificDatumReader<AdRequest> reader = new SpecificDatumReader<AdRequest>(
				AdRequest.class);

		try {
			// Should only be 1 request object
			adRequest = reader.read(null, decoder);

			System.out.println("Read Request: " + adRequest);
			return adRequest;

		} catch (EOFException eof) {
			System.err.println("End of file: " + eof.getMessage());
		} catch (Exception ex) {
			System.err
					.println("Error in processing request " + ex.getMessage());
		}

		return adRequest;
	}

	protected byte[] getResponse(AdRequest request, String returnFormat)
			throws IOException {
		// Demonstrate ad generation or error output
		AdResponse adResponse = null;

		if (request.getAdSpaceName().toString().equalsIgnoreCase("throwError")) {
			List<CharSequence> errors = new ArrayList<CharSequence>();
			errors.add((CharSequence) "Ad server has exploded.");
			adResponse = AdResponse.newBuilder().setErrors(errors).setAds(new ArrayList<Ad>()).build();
		} else {
			// Generate a couple of sample ads
			List<Ad> ads = new ArrayList<Ad>();

			// Get Ad Space name from request and just make up a name of an Ad
			Ad ad1 = Ad.newBuilder().setAdSpace(request.getAdSpaceName())
					.setAdName("Awesome App").build();
			Ad ad2 = Ad.newBuilder().setAdSpace(request.getAdSpaceName())
					.setAdName("Even better App").build();
			ads.add(ad1);
			ads.add(ad2);

			adResponse = AdResponse.newBuilder().setAds(ads).build();
		}

		SpecificDatumWriter<AdResponse> writer = new SpecificDatumWriter<AdResponse>(
				AdResponse.class);
		ByteArrayOutputStream out = new ByteArrayOutputStream();

		if (returnFormat.equals(BINARY_CONTENT_TYPE)) {
			System.out.println("Returning binary");

			BinaryEncoder encoder = EncoderFactory.get().binaryEncoder(out,
					null);
			writer.write(adResponse, encoder);
			encoder.flush();
			ByteBuffer serialized = ByteBuffer
					.allocate(out.toByteArray().length);
			serialized.put(out.toByteArray());

			return serialized.array();
		} else {
			System.out.println("Returning json");

			JsonEncoder jsonEncoder = EncoderFactory.get().jsonEncoder(
					AdResponse.SCHEMA$, out);
			writer.write(adResponse, jsonEncoder);
			jsonEncoder.flush();
			return out.toByteArray();

		}

	}

	static class WebHandler extends AbstractHandler {

		private AvroServer avroServer;

		public WebHandler(AvroServer avroServer) {
			this.avroServer = avroServer;
		}

		@Override
		public void handle(String target, Request baseRequest,
				HttpServletRequest request, HttpServletResponse response)
				throws IOException, ServletException {
			response.setStatus(HttpServletResponse.SC_OK);

			final String url = request.getRequestURI();

			try {
				System.out.println("URL: " + url + " Method: "
						+ request.getMethod());


				//look into using URLS for long term
				//check schema type and respond appropriately

				//if GET for pref, don't read body
				//if POST for pref, update pref

				//if POST for metrics, update


				GenericRecord record = avroServer.readRequest(request.getInputStream(),
						request.getContentType(),
						request.getHeader("X-Avro-Schema-Name"),
						request.getIntHeader("X-Avro-Schema-Version"));


//				// Read Avro request
//				AdRequest adRequest = avroServer.readRequest(
//						request.getInputStream(), request.getContentType());
//
//				// First determined return format. If accept header is specified
//				// use that, else refer to the content type
//				String acceptHeader = request.getHeader("accept");
//				String contentType = request.getContentType();
//				String returnFormat = acceptHeader != null
//						&& (acceptHeader.equals(BINARY_CONTENT_TYPE) || acceptHeader
//								.equals(JSON_CONTENT_TYPE)) ? acceptHeader
//						: contentType;
//
//				// Process request object to get response
//				byte[] adResponse = avroServer.getResponse(adRequest,
//						returnFormat);
//
//				if (adResponse != null)
//				{
//					response.setContentLength(adResponse.length);
//					response.setContentType(returnFormat);
//					response.getOutputStream().write(adResponse);
//				}
			} catch (IllegalArgumentException e) {
				System.err.println(e.getMessage());
				response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
			}
			((Request) request).setHandled(true);
		}
	}
}
